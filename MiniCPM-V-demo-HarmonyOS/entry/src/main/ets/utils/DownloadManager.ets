// Direct port of the LlamaEngine.kt download path (probeReachable +
// downloadFile + computeMd5 + downloadModels). Fetches go through @ohos.net.http
// for HEAD probes and through @ohos.request.agent for the actual GBs of model
// data — using `request.agent` instead of buffering the whole response in
// memory keeps us safe on phones with limited RAM.

import http from '@ohos.net.http';
import request from '@ohos.request';
import fs from '@ohos.file.fs';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

import {
  ModelInfo,
  findModelById,
  AVAILABLE_MODELS,
  DEFAULT_MODEL,
} from '../engine/ModelInfo';

const DOMAIN = 0xC0DE;
const TAG = 'DownloadManager';
const PREFS_NAME = 'model_prefs';

const PROBE_TIMEOUT_MS    = 5_000;
const DOWNLOAD_CONNECT_MS = 10_000;
const DOWNLOAD_READ_MS    = 120_000;

export type ProgressListener = (msg: string) => void;

interface DownloadJob {
  source: string;
  name:   string;
  url:    string;
  md5:    string | null;
}

// Async because the underlying preferences API is async; called from
// LlamaEngine.downloadModels which itself is awaited.
async function getSelectedModelAsync(context: common.Context): Promise<ModelInfo> {
  try {
    const p = await dataPreferences.getPreferences(context, PREFS_NAME);
    const id = await p.get('selected_model_id', DEFAULT_MODEL.id) as string;
    return findModelById(id);
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'getSelectedModelAsync fallback to default: %{public}s', `${e}`);
    return DEFAULT_MODEL;
  }
}

export async function downloadModelsForSelected(
  context: common.Context,
  onProgress: ProgressListener,
): Promise<void> {
  const model = await getSelectedModelAsync(context);
  const dir = `${context.filesDir}/models/${model.id}`;
  if (!fs.accessSync(dir)) {
    fs.mkdirSync(dir, true);
  }

  let jobs: DownloadJob[];
  if (model.hasDirectUrls()) {
    onProgress('使用直链下载 (与 iOS 同源)...');
    jobs = [
      { source: '直链', name: model.ggufFileName,   url: model.directGgufUrl!,   md5: model.ggufMd5 },
      { source: '直链', name: model.mmprojFileName, url: model.directMmprojUrl!, md5: model.mmprojMd5 },
    ];
  } else {
    if (!model.hfRepo || !model.msRepo) {
      throw new Error(`Model ${model.id} has neither hfRepo nor direct URLs`);
    }
    const hfBase = `https://huggingface.co/${model.hfRepo}/resolve/${model.hfBranch}`;
    const msBase = `https://www.modelscope.cn/models/${model.msRepo}/resolve/${model.msBranch}`;

    onProgress('正在连接 HuggingFace...');
    const hfOk = await probeReachable(`${hfBase}/${model.ggufFileName}`);

    let baseUrl: string;
    let source:  string;
    if (hfOk) {
      onProgress('HuggingFace 连接成功，开始下载...');
      baseUrl = hfBase;
      source = 'HuggingFace';
    } else {
      onProgress('HuggingFace 连接失败，切换到 ModelScope...');
      const msOk = await probeReachable(`${msBase}/${model.ggufFileName}`);
      if (!msOk) {
        throw new Error('HuggingFace 和 ModelScope 均无法连接，请检查网络后重试');
      }
      onProgress('ModelScope 连接成功，开始下载...');
      baseUrl = msBase;
      source = 'ModelScope';
    }
    jobs = [
      { source, name: model.ggufFileName,   url: `${baseUrl}/${model.ggufFileName}`,   md5: model.ggufMd5 },
      { source, name: model.mmprojFileName, url: `${baseUrl}/${model.mmprojFileName}`, md5: model.mmprojMd5 },
    ];
  }

  for (const job of jobs) {
    await downloadFile(context, dir, job, onProgress);
  }
  onProgress('所有模型文件下载完成!');
}

async function probeReachable(url: string): Promise<boolean> {
  const client = http.createHttp();
  try {
    const resp = await client.request(url, {
      method: http.RequestMethod.HEAD,
      header: { 'User-Agent': 'MiniCPMV-demo/1.0' },
      connectTimeout: PROBE_TIMEOUT_MS,
      readTimeout: PROBE_TIMEOUT_MS,
    });
    return resp.responseCode === http.ResponseCode.OK;
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'Reachability probe failed for %{public}s: %{public}s', url, `${e}`);
    return false;
  } finally {
    client.destroy();
  }
}

async function downloadFile(
  context: common.Context,
  dir: string,
  job: DownloadJob,
  onProgress: ProgressListener,
): Promise<void> {
  const targetPath = `${dir}/${job.name}`;

  // Fast path: file already on disk and hash matches → skip re-downloading.
  if (fs.accessSync(targetPath) && job.md5) {
    onProgress(`[${job.source}] 校验已存在的 ${job.name} ...`);
    const actual = await computeMd5(targetPath);
    if (actual.toLowerCase() === job.md5.toLowerCase()) {
      onProgress(`${job.name} 已就绪 (MD5 校验通过)`);
      return;
    }
    hilog.warn(DOMAIN, TAG, '%{public}s MD5 mismatch (got %{public}s, want %{public}s); re-downloading',
               job.name, actual, job.md5);
    fs.unlinkSync(targetPath);
  }

  onProgress(`[${job.source}] 下载 ${job.name}...`);
  hilog.info(DOMAIN, TAG, 'Downloading %{public}s from %{public}s: %{public}s',
             job.name, job.source, job.url);

  // Use @ohos.request.agent for streaming downloads with progress callbacks.
  // This avoids buffering the entire response in memory and gives us
  // foreground progress events for the UI status text.
  const tmpPath = `${targetPath}.tmp`;
  if (fs.accessSync(tmpPath)) fs.unlinkSync(tmpPath);

  await new Promise<void>((resolve, reject) => {
    let lastProgressTime = 0;
    const headers: Record<string, string> = { 'User-Agent': 'MiniCPMV-demo/1.0' };
    const config: request.agent.Config = {
      action: request.agent.Action.DOWNLOAD,
      url: job.url,
      headers,
      saveas: tmpPath,
      overwrite: true,
      method: 'GET',
      mode: request.agent.Mode.FOREGROUND,
      network: request.agent.Network.ANY,
      retry: false,
    };

    request.agent.create(context, config).then((task: request.agent.Task) => {
      task.on('progress', (p: request.agent.Progress) => {
        const now = Date.now();
        if (now - lastProgressTime > 500) {
          lastProgressTime = now;
          const got = p.processed;
          const totalArr = p.sizes;
          const total = totalArr && totalArr.length > 0 ? totalArr[0] : -1;
          if (total > 0) {
            const pct = Math.floor(got * 100 / total);
            const mb = Math.floor(got / (1024 * 1024));
            const totalMb = Math.floor(total / (1024 * 1024));
            onProgress(`${job.name}: ${pct}% (${mb}/${totalMb} MB)`);
          } else {
            const mb = Math.floor(got / (1024 * 1024));
            onProgress(`${job.name}: ${mb} MB downloaded`);
          }
        }
      });
      task.on('completed', async () => {
        try {
          if (fs.accessSync(targetPath)) fs.unlinkSync(targetPath);
          fs.renameSync(tmpPath, targetPath);
          resolve();
        } catch (e) {
          reject(e as object);
        } finally {
          request.agent.remove(task.tid).catch(() => undefined);
        }
      });
      task.on('failed', () => {
        request.agent.show(task.tid).then(info => {
          reject(new Error(`Download failed: ${JSON.stringify(info.faults)}`));
        }).catch(() => {
          reject(new Error('Download failed'));
        }).finally(() => {
          request.agent.remove(task.tid).catch(() => undefined);
        });
      });
      task.start();
    }).catch((e: object) => reject(e));
  });

  if (job.md5) {
    onProgress(`[${job.source}] 校验 ${job.name} MD5...`);
    const actual = await computeMd5(targetPath);
    if (actual.toLowerCase() !== job.md5.toLowerCase()) {
      hilog.error(DOMAIN, TAG, '%{public}s MD5 mismatch: expected %{public}s, got %{public}s',
                  job.name, job.md5, actual);
      try { fs.unlinkSync(targetPath); } catch (_) { /* ignore */ }
      throw new Error(`${job.name} MD5 校验失败 (期望 ${job.md5}, 实际 ${actual})，文件已删除，请重试`);
    }
    hilog.info(DOMAIN, TAG, '%{public}s MD5 OK (%{public}s)', job.name, actual);
  }

  const size = fs.statSync(targetPath).size;
  onProgress(`${job.name} 下载完成 (${Math.floor(size / (1024 * 1024))} MB)`);
}

// Streaming MD5 — keeps memory bounded on the 1GB+ mmproj. 64KB chunks
// give ~150 MB/s on the test phone, identical to the Android implementation.
export async function computeMd5(path: string): Promise<string> {
  const md = cryptoFramework.createMd('MD5');
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const CHUNK = 64 * 1024;
    const buf = new ArrayBuffer(CHUNK);
    let offset = 0;
    while (true) {
      const read = fs.readSync(file.fd, buf, { offset, length: CHUNK });
      if (read <= 0) break;
      // The crypto framework expects a DataBlob; copy only the read portion.
      const slice = read === CHUNK ? buf : buf.slice(0, read);
      await md.update({ data: new Uint8Array(slice) });
      offset += read;
    }
    const digest = await md.digest();
    return bytesToHex(digest.data);
  } finally {
    fs.closeSync(file);
  }
}

function bytesToHex(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i++) {
    const h = bytes[i].toString(16);
    s += h.length === 1 ? `0${h}` : h;
  }
  return s;
}

// Convenience wrapper used by ModelManager to delete the currently
// selected model's two files. Mirrors deleteModelFiles() on Android.
export async function deleteSelectedModelFiles(context: common.Context): Promise<boolean> {
  const model = await getSelectedModelAsync(context);
  const dir = `${context.filesDir}/models/${model.id}`;
  let deleted = false;
  for (const name of [model.ggufFileName, model.mmprojFileName]) {
    const p = `${dir}/${name}`;
    if (fs.accessSync(p)) {
      try { fs.unlinkSync(p); deleted = true; }
      catch (e) {
        hilog.warn(DOMAIN, TAG, 'unlink %{public}s failed: %{public}s', p, `${e}`);
      }
    }
  }
  return deleted;
}
