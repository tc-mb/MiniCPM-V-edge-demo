#include <android/log.h>
#include <jni.h>
#include <iomanip>
#include <cmath>
#include <string>
#include <unistd.h>
#include <vector>

#include "logging.h"
#include "chat.h"
#include "common.h"
#include "llama.h"
#include "sampling.h"
#include "mtmd.h"
#include "mtmd-helper.h"

template<class T>
static std::string join(const std::vector<T> &values, const std::string &delim) {
    std::ostringstream str;
    for (size_t i = 0; i < values.size(); i++) {
        str << values[i];
        if (i < values.size() - 1) { str << delim; }
    }
    return str.str();
}

constexpr int   N_THREADS_MIN           = 2;
constexpr int   N_THREADS_MAX           = 5;
constexpr int   N_THREADS_HEADROOM      = 0;

constexpr int   DEFAULT_CONTEXT_SIZE    = 4096;
constexpr int   OVERFLOW_HEADROOM       = 4;
constexpr int   BATCH_SIZE              = 512;
constexpr float DEFAULT_SAMPLER_TEMP    = 0.2f;

static llama_model                      * g_model;
static llama_context                    * g_context;
static llama_batch                        g_batch;
static common_chat_templates_ptr          g_chat_templates;
static common_sampler                   * g_sampler;
static mtmd_context                     * g_ctx_vision;

extern "C"
JNIEXPORT void JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_init(JNIEnv *env, jobject /*unused*/, jstring nativeLibDir) {
    llama_log_set(minicpm_android_log_callback, nullptr);
    mtmd_helper_log_set(minicpm_android_log_callback, nullptr);

    const auto *path_to_backend = env->GetStringUTFChars(nativeLibDir, 0);
    LOGi("Loading backends from %s", path_to_backend);
    ggml_backend_load_all_from_path(path_to_backend);
    env->ReleaseStringUTFChars(nativeLibDir, path_to_backend);

    if (ggml_backend_reg_count() == 0) {
        LOGw("%s: No backends loaded from path, trying ggml_backend_load_all()", __func__);
        ggml_backend_load_all();
    }

    LOGi("%s: Backend count: %zu", __func__, ggml_backend_reg_count());

    llama_backend_init();
    LOGi("Backend initiated; Log handler set.");
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_load(JNIEnv *env, jobject, jstring jmodel_path) {
    llama_model_params model_params = llama_model_default_params();

    const auto *model_path = env->GetStringUTFChars(jmodel_path, 0);
    LOGi("%s: Loading model from: \n%s\n", __func__, model_path);

    FILE *f = fopen(model_path, "rb");
    if (!f) {
        LOGe("%s: Cannot open model file! Permission denied or file not found: %s", __func__, model_path);
        env->ReleaseStringUTFChars(jmodel_path, model_path);
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    fclose(f);
    LOGi("%s: Model file size: %ld bytes (%.2f GB)", __func__, file_size, file_size / (1024.0 * 1024.0 * 1024.0));

    auto *model = llama_model_load_from_file(model_path, model_params);
    env->ReleaseStringUTFChars(jmodel_path, model_path);
    if (!model) {
        LOGe("%s: llama_model_load_from_file returned null! Check logcat for llama.cpp internal errors.", __func__);
        return 2;
    }
    g_model = model;
    LOGi("%s: Model loaded successfully!", __func__);
    return 0;
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_loadMmproj(JNIEnv *env, jobject, jstring jmmproj_path) {
    if (!g_model) {
        LOGe("%s: Base model must be loaded first!", __func__);
        return 1;
    }

    const auto *mmproj_path = env->GetStringUTFChars(jmmproj_path, 0);
    LOGd("%s: Loading mmproj from: \n%s\n", __func__, mmproj_path);

    mtmd_context_params mparams = mtmd_context_params_default();
    mparams.use_gpu   = false;
    mparams.print_timings = false;

    // On mobile we skip MiniCPM-V's high-resolution slicing (1 overview only,
    // ~9x fewer image tokens, much faster prefill at the cost of small-detail
    // recognition). Set to -1 (or remove) to use the model default of 9 slices.
    mparams.image_max_slice_nums = 1;

    const int n_threads = std::max(N_THREADS_MIN, std::min(N_THREADS_MAX,
                                                 (int) sysconf(_SC_NPROCESSORS_ONLN) -
                                                 N_THREADS_HEADROOM));
    mparams.n_threads = n_threads;

    g_ctx_vision = mtmd_init_from_file(mmproj_path, g_model, mparams);
    env->ReleaseStringUTFChars(jmmproj_path, mmproj_path);

    if (!g_ctx_vision) {
        LOGe("%s: Failed to load mmproj model!", __func__);
        return 2;
    }

    LOGi("%s: mmproj model loaded successfully! Vision: %s",
         __func__, mtmd_support_vision(g_ctx_vision) ? "yes" : "no");
    return 0;
}

static llama_context *init_context(llama_model *model, const int n_ctx = DEFAULT_CONTEXT_SIZE) {
    if (!model) {
        LOGe("%s: model cannot be null", __func__);
        return nullptr;
    }

    const int n_threads = std::max(N_THREADS_MIN, std::min(N_THREADS_MAX,
                                                     (int) sysconf(_SC_NPROCESSORS_ONLN) -
                                                     N_THREADS_HEADROOM));
    LOGi("%s: Using %d threads", __func__, n_threads);

    llama_context_params ctx_params = llama_context_default_params();
    const int trained_context_size = llama_model_n_ctx_train(model);
    if (n_ctx > trained_context_size) {
        LOGw("%s: Model was trained with only %d context size! Enforcing %d context size...",
             __func__, trained_context_size, n_ctx);
    }
    ctx_params.n_ctx = n_ctx;
    ctx_params.n_batch = BATCH_SIZE;
    ctx_params.n_ubatch = BATCH_SIZE;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;
    auto *context = llama_init_from_model(g_model, ctx_params);
    if (context == nullptr) {
        LOGe("%s: llama_new_context_with_model() returned null)", __func__);
    }
    return context;
}

static common_sampler *new_sampler(float temp) {
    common_params_sampling sparams;
    sparams.temp = temp;
    sparams.top_k = 100;
    sparams.top_p = 0.8f;
    sparams.penalty_repeat = 1.05f;
    return common_sampler_init(g_model, sparams);
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_prepare(JNIEnv * /*env*/, jobject /*unused*/) {
    auto *context = init_context(g_model);
    if (!context) { return 1; }
    g_context = context;
    g_batch = llama_batch_init(BATCH_SIZE, 0, 1);
    g_chat_templates = common_chat_templates_init(g_model, "");
    g_sampler = new_sampler(DEFAULT_SAMPLER_TEMP);
    return 0;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_systemInfo(JNIEnv *env, jobject /*unused*/) {
    return env->NewStringUTF(llama_print_system_info());
}

constexpr const char *ROLE_SYSTEM       = "system";
constexpr const char *ROLE_USER         = "user";
constexpr const char *ROLE_ASSISTANT    = "assistant";

static std::vector<common_chat_msg> chat_msgs;
static llama_pos system_prompt_position;
static llama_pos current_position;
static llama_pos generation_start_position;
static bool g_image_prefilled = false;
static bool g_vision_mode = false;

static void reset_long_term_states(const bool clear_kv_cache = true) {
    chat_msgs.clear();
    system_prompt_position = 0;
    current_position = 0;
    g_image_prefilled = false;
    g_vision_mode = false;

    if (clear_kv_cache)
        llama_memory_clear(llama_get_memory(g_context), false);
}

static void shift_context() {
    const int n_discard = (current_position - system_prompt_position) / 2;
    LOGi("%s: Discarding %d tokens", __func__, n_discard);
    llama_memory_seq_rm(llama_get_memory(g_context), 0, system_prompt_position, system_prompt_position + n_discard);
    llama_memory_seq_add(llama_get_memory(g_context), 0, system_prompt_position + n_discard, current_position, -n_discard);
    current_position -= n_discard;
    LOGi("%s: Context shifting done! Current position: %d", __func__, current_position);
}

static std::string chat_add_and_format(const std::string &role, const std::string &content) {
    common_chat_msg new_msg;
    new_msg.role = role;
    new_msg.content = content;
    auto formatted = common_chat_format_single(
            g_chat_templates.get(), chat_msgs, new_msg, role == ROLE_USER, false);
    chat_msgs.push_back(new_msg);
    LOGi("%s: Formatted and added %s message: \n%s\n", __func__, role.c_str(), formatted.c_str());
    return formatted;
}

static llama_pos stop_generation_position;
static std::string cached_token_chars;
static std::ostringstream assistant_ss;

static void reset_short_term_states() {
    stop_generation_position = 0;
    cached_token_chars.clear();
    assistant_ss.str("");
}

static int decode_tokens_in_batches(
        llama_context *context,
        llama_batch &batch,
        const llama_tokens &tokens,
        const llama_pos start_pos,
        const bool compute_last_logit = false) {
    LOGd("%s: Decode %d tokens starting at position %d", __func__, (int) tokens.size(), start_pos);
    for (int i = 0; i < (int) tokens.size(); i += BATCH_SIZE) {
        const int cur_batch_size = std::min((int) tokens.size() - i, BATCH_SIZE);
        common_batch_clear(batch);
        LOGv("%s: Preparing a batch size of %d starting at: %d", __func__, cur_batch_size, i);

        if (start_pos + i + cur_batch_size >= DEFAULT_CONTEXT_SIZE - OVERFLOW_HEADROOM) {
            LOGw("%s: Current batch won't fit into context! Shifting...", __func__);
            shift_context();
        }

        for (int j = 0; j < cur_batch_size; j++) {
            const llama_token token_id = tokens[i + j];
            const llama_pos position = start_pos + i + j;
            const bool want_logit = compute_last_logit && (i + j == tokens.size() - 1);
            common_batch_add(batch, token_id, position, {0}, want_logit);
        }

        const int decode_result = llama_decode(context, batch);
        if (decode_result) {
            LOGe("%s: llama_decode failed w/ %d", __func__, decode_result);
            return 1;
        }
    }
    return 0;
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_processSystemPrompt(
        JNIEnv *env,
        jobject /*unused*/,
        jstring jsystem_prompt
) {
    reset_short_term_states();

    const auto *system_prompt = env->GetStringUTFChars(jsystem_prompt, nullptr);
    LOGd("%s: System prompt received: \n%s", __func__, system_prompt);
    std::string formatted_system_prompt(system_prompt);

    const bool has_chat_template = common_chat_templates_was_explicit(g_chat_templates.get());
    if (has_chat_template) {
        formatted_system_prompt = chat_add_and_format(ROLE_SYSTEM, system_prompt);
    }
    env->ReleaseStringUTFChars(jsystem_prompt, system_prompt);

    if (g_ctx_vision) {
        mtmd_input_text input_text;
        input_text.text = formatted_system_prompt.c_str();
        input_text.add_special = current_position == 0;
        input_text.parse_special = true;

        mtmd_input_chunks * chunks = mtmd_input_chunks_init();
        int32_t res = mtmd_tokenize(g_ctx_vision, chunks, &input_text, nullptr, 0);
        if (res != 0) {
            LOGe("%s: mtmd_tokenize failed with code %d", __func__, res);
            mtmd_input_chunks_free(chunks);
            return 2;
        }

        llama_pos new_n_past;
        if (mtmd_helper_eval_chunks(g_ctx_vision, g_context, chunks,
                                    current_position, 0, BATCH_SIZE,
                                    true, &new_n_past)) {
            LOGe("%s: mtmd_helper_eval_chunks failed!", __func__);
            mtmd_input_chunks_free(chunks);
            return 2;
        }

        current_position = new_n_past;
        generation_start_position = current_position;
        mtmd_input_chunks_free(chunks);
    } else {
        const auto system_tokens = common_tokenize(g_context, formatted_system_prompt,
                                                   current_position == 0, true);
        for (auto id: system_tokens) {
            LOGv("token: `%s`\t -> `%d`", common_token_to_piece(g_context, id).c_str(), id);
        }

        const int max_batch_size = DEFAULT_CONTEXT_SIZE - OVERFLOW_HEADROOM;
        if ((int) system_tokens.size() > max_batch_size) {
            LOGe("%s: System prompt too long for context! %d tokens, max: %d",
                 __func__, (int) system_tokens.size(), max_batch_size);
            return 1;
        }

        if (decode_tokens_in_batches(g_context, g_batch, system_tokens, current_position, true)) {
            LOGe("%s: llama_decode() failed!", __func__);
            return 2;
        }

        current_position += (int) system_tokens.size();
    }

    system_prompt_position = current_position;
    return 0;
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_prefillImage(
        JNIEnv *env,
        jobject /*unused*/,
        jbyteArray jimage_data,
        jint jimage_size
) {
    if (!g_ctx_vision) {
        LOGe("%s: mmproj not loaded!", __func__);
        return 1;
    }

    jbyte *data = env->GetByteArrayElements(jimage_data, nullptr);
    if (!data) {
        LOGe("%s: Failed to get image data from Java", __func__);
        return 2;
    }

    auto *bitmap = mtmd_helper_bitmap_init_from_buf(
        g_ctx_vision,
        reinterpret_cast<const unsigned char *>(data),
        static_cast<size_t>(jimage_size)
    );

    env->ReleaseByteArrayElements(jimage_data, data, JNI_ABORT);

    if (!bitmap) {
        LOGe("%s: Failed to create bitmap from image buffer", __func__);
        return 3;
    }

    mtmd_input_text text;
    text.text = mtmd_default_marker();
    text.add_special = current_position == 0;
    text.parse_special = true;

    mtmd_input_chunks * chunks = mtmd_input_chunks_init();
    const mtmd_bitmap * bitmaps_cptr[] = { bitmap };
    int32_t res = mtmd_tokenize(g_ctx_vision, chunks, &text,
                                bitmaps_cptr, 1);

    mtmd_bitmap_free(bitmap);

    if (res != 0) {
        LOGe("%s: mtmd_tokenize failed with code %d", __func__, res);
        mtmd_input_chunks_free(chunks);
        return 4;
    }

    llama_pos new_n_past;
    if (mtmd_helper_eval_chunks(g_ctx_vision, g_context, chunks,
                                current_position, 0, BATCH_SIZE,
                                false, &new_n_past)) {
        LOGe("%s: mtmd_helper_eval_chunks failed!", __func__);
        mtmd_input_chunks_free(chunks);
        return 5;
    }

    current_position = new_n_past;
    mtmd_input_chunks_free(chunks);
    g_image_prefilled = true;
    g_vision_mode = true;

    LOGi("%s: Image prefilled, current_position: %d", __func__, current_position);
    return 0;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_fullReset(JNIEnv *, jobject) {
    reset_long_term_states();
    reset_short_term_states();

    common_sampler_free(g_sampler);
    g_sampler = nullptr;
    g_chat_templates.reset();
    llama_batch_free(g_batch);
    llama_free(g_context);
    g_context = nullptr;

    auto *context = init_context(g_model);
    if (!context) {
        LOGe("%s: Failed to reinitialize context!", __func__);
        return;
    }
    g_context = context;
    g_batch = llama_batch_init(BATCH_SIZE, 0, 1);
    g_chat_templates = common_chat_templates_init(g_model, "");
    g_sampler = new_sampler(DEFAULT_SAMPLER_TEMP);

    LOGi("%s: Full reset complete - context recreated, KV cache fresh, sampler reinitialized", __func__);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_nativeCancelGeneration(JNIEnv *, jobject) {
    common_sampler_reset(g_sampler);
    assistant_ss.str("");
    assistant_ss.clear();
    cached_token_chars.clear();
    LOGi("%s: Generation cancelled, sampler reset, KV cache preserved at position %d",
         __func__, current_position);
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_processUserPrompt(
        JNIEnv *env,
        jobject /*unused*/,
        jstring juser_prompt,
        jint n_predict
) {
    reset_short_term_states();

    const auto *const user_prompt = env->GetStringUTFChars(juser_prompt, nullptr);
    LOGd("%s: User prompt received: \n%s", __func__, user_prompt);

    std::string content_for_format(user_prompt);
    if (content_for_format.empty()) {
        content_for_format = " ";
    }

    std::string formatted_user_prompt;
    if (g_ctx_vision) {
        if (current_position == 0) {
            formatted_user_prompt += "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n";
        }
        formatted_user_prompt += "<|im_start|>user\n" + content_for_format + "<|im_end|>\n";
        if (g_vision_mode) {
            formatted_user_prompt += "<|im_start|>assistant\n thinking\n\n response\n\n";
        } else {
            formatted_user_prompt += "<|im_start|>assistant\n";
        }

        common_chat_msg new_msg;
        new_msg.role = ROLE_USER;
        new_msg.content = content_for_format;
        chat_msgs.push_back(new_msg);

        LOGi("%s: Formatted user prompt (iOS-style manual, image=%s): \n%s\n",
             __func__, g_image_prefilled ? "yes" : "no", formatted_user_prompt.c_str());

        g_image_prefilled = false;
    } else {
        const bool has_chat_template = common_chat_templates_was_explicit(g_chat_templates.get());
        if (has_chat_template) {
            formatted_user_prompt = chat_add_and_format(ROLE_USER, content_for_format.c_str());
        } else {
            formatted_user_prompt = content_for_format;
        }
    }
    env->ReleaseStringUTFChars(juser_prompt, user_prompt);

    if (g_ctx_vision) {
        mtmd_input_text text;
        text.text          = formatted_user_prompt.c_str();
        text.add_special   = current_position == 0;
        text.parse_special = true;

        mtmd_input_chunks * chunks = mtmd_input_chunks_init();
        int32_t res = mtmd_tokenize(g_ctx_vision, chunks, &text, nullptr, 0);
        if (res != 0) {
            LOGe("%s: mtmd_tokenize failed with code %d", __func__, res);
            mtmd_input_chunks_free(chunks);
            return 2;
        }

        llama_pos new_n_past;
        if (mtmd_helper_eval_chunks(g_ctx_vision, g_context, chunks,
                                    current_position, 0, BATCH_SIZE,
                                    true, &new_n_past)) {
            LOGe("%s: mtmd_helper_eval_chunks failed!", __func__);
            mtmd_input_chunks_free(chunks);
            return 2;
        }

        current_position = new_n_past;
        generation_start_position = current_position;
        mtmd_input_chunks_free(chunks);
    } else {
        auto user_tokens = common_tokenize(g_context, formatted_user_prompt, current_position == 0, true);
        for (auto id: user_tokens) {
            LOGv("token: `%s`\t -> `%d`", common_token_to_piece(g_context, id).c_str(), id);
        }

        const int user_prompt_size = (int) user_tokens.size();
        const int max_batch_size = DEFAULT_CONTEXT_SIZE - OVERFLOW_HEADROOM;
        if (user_prompt_size > max_batch_size) {
            const int skipped_tokens = user_prompt_size - max_batch_size;
            user_tokens.resize(max_batch_size);
            LOGw("%s: User prompt too long! Skipped %d tokens!", __func__, skipped_tokens);
        }

        if (decode_tokens_in_batches(g_context, g_batch, user_tokens, current_position, true)) {
            LOGe("%s: llama_decode() failed!", __func__);
            return 2;
        }

        current_position += user_prompt_size;
        generation_start_position = current_position;
    }

    stop_generation_position = current_position + n_predict;
    return 0;
}

static bool is_valid_utf8(const char *string) {
    if (!string) { return true; }

    const auto *bytes = (const unsigned char *) string;
    int num;

    while (*bytes != 0x00) {
        if ((*bytes & 0x80) == 0x00) {
            num = 1;
        } else if ((*bytes & 0xE0) == 0xC0) {
            num = 2;
        } else if ((*bytes & 0xF0) == 0xE0) {
            num = 3;
        } else if ((*bytes & 0xF8) == 0xF0) {
            num = 4;
        } else {
            return false;
        }

        bytes += 1;
        for (int i = 1; i < num; ++i) {
            if ((*bytes & 0xC0) != 0x80) {
                return false;
            }
            bytes += 1;
        }
    }
    return true;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_generateNextToken(
        JNIEnv *env,
        jobject /*unused*/
) {
    if (current_position >= DEFAULT_CONTEXT_SIZE - OVERFLOW_HEADROOM) {
        LOGw("%s: Context full! Shifting...", __func__);
        shift_context();
    }

    if (current_position >= stop_generation_position) {
        LOGw("%s: STOP: hitting stop position: %d", __func__, stop_generation_position);
        return nullptr;
    }

    const auto new_token_id = common_sampler_sample(g_sampler, g_context, -1);
    common_sampler_accept(g_sampler, new_token_id, true);

    const bool is_eog = llama_vocab_is_eog(llama_model_get_vocab(g_model), new_token_id);

    common_batch_clear(g_batch);
    common_batch_add(g_batch, new_token_id, current_position, {0}, true);
    if (llama_decode(g_context, g_batch) != 0) {
        LOGe("%s: llama_decode() failed for generated token", __func__);
        return nullptr;
    }

    current_position++;

    if (is_eog) {
        LOGd("id: %d,\tIS EOG!\nSTOP.", new_token_id);
        chat_add_and_format(ROLE_ASSISTANT, assistant_ss.str());
        return nullptr;
    }

    auto new_token_chars = common_token_to_piece(g_context, new_token_id);
    cached_token_chars += new_token_chars;

    jstring result = nullptr;
    if (is_valid_utf8(cached_token_chars.c_str())) {
        result = env->NewStringUTF(cached_token_chars.c_str());
        LOGv("id: %d,\tcached: `%s`,\tnew: `%s`", new_token_id, cached_token_chars.c_str(), new_token_chars.c_str());

        assistant_ss << cached_token_chars;
        cached_token_chars.clear();
    } else {
        LOGv("id: %d,\tappend to cache", new_token_id);
        result = env->NewStringUTF("");
    }
    return result;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_unload(JNIEnv * /*env*/, jobject /*unused*/) {
    reset_long_term_states();
    reset_short_term_states();

    if (g_ctx_vision) {
        mtmd_free(g_ctx_vision);
        g_ctx_vision = nullptr;
    }

    common_sampler_free(g_sampler);
    g_chat_templates.reset();
    llama_batch_free(g_batch);
    llama_free(g_context);
    llama_model_free(g_model);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_minicpm_1v_1demo_LlamaEngine_shutdown(JNIEnv *, jobject /*unused*/) {
    llama_backend_free();
}
