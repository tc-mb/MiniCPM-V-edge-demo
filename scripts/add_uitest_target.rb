#!/usr/bin/env ruby
# frozen_string_literal: true
#
# 给 MiniCPM-V-demo.xcodeproj 添加一个 UI Test target（MiniCPM-V-demoUITests）。
# 已经存在则跳过。
#
# 用法:
#   DEVELOPMENT_TEAM=YOUR_TEAM_ID ruby scripts/add_uitest_target.rb
#   # 真机测试需要设 DEVELOPMENT_TEAM；模拟器测试可以省略。
#
# 可选环境变量:
#   DEVELOPMENT_TEAM   你的 Apple 开发者 Team ID（10 位字符），不设则不写入工程
#   UITEST_BUNDLE_ID   UI 测试 bundle id，默认 com.example.minicpmvdemo.uitests
#
# 依赖:
#   gem install --user-install xcodeproj
#

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../MiniCPM-V-demo.xcodeproj', __dir__)
APP_TARGET_NAME = 'MiniCPM-V-demo'
TEST_TARGET_NAME = 'MiniCPM-V-demoUITests'
TEST_BUNDLE_ID = ENV['UITEST_BUNDLE_ID'] || 'com.example.minicpmvdemo.uitests'
DEVELOPMENT_TEAM = ENV['DEVELOPMENT_TEAM'] || ''
DEPLOYMENT_TARGET = '16.6'
SWIFT_VERSION = '5.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.find { |t| t.name == TEST_TARGET_NAME }
  puts "[skip] Target '#{TEST_TARGET_NAME}' already exists."
  exit 0
end

app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
raise "App target '#{APP_TARGET_NAME}' not found" unless app_target

# 1. 创建 PBXNativeTarget (UI Test bundle)
test_target = project.new_target(
  :ui_test_bundle,
  TEST_TARGET_NAME,
  :ios,
  DEPLOYMENT_TARGET,
  project.products_group,
  :swift
)

# 2. 添加测试源文件 group + file ref
test_group = project.main_group.find_subpath(TEST_TARGET_NAME, true)
test_group.set_source_tree('SOURCE_ROOT')
test_group.set_path(TEST_TARGET_NAME)

swift_file_ref = test_group.new_reference('MiniCPMVDemoUITests.swift')
swift_file_ref.last_known_file_type = 'sourcecode.swift'
test_target.add_file_references([swift_file_ref])

# Info.plist 不通过 sources phase 添加，只在 build settings 引用
plist_file_ref = test_group.new_reference('Info.plist')
plist_file_ref.last_known_file_type = 'text.plist.xml'

# 3. Build Settings：和主 target 对齐签名/部署版本
test_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = TEST_BUNDLE_ID
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  bs['SWIFT_VERSION'] = SWIFT_VERSION
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM unless DEVELOPMENT_TEAM.empty?
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['CODE_SIGN_IDENTITY'] = 'Apple Development'
  bs['INFOPLIST_FILE'] = "#{TEST_TARGET_NAME}/Info.plist"
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['TEST_TARGET_NAME'] = APP_TARGET_NAME
  bs['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'
  bs['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  bs['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = config.name == 'Debug' ? 'DEBUG' : ''
  bs['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

# 4. 给主 target 加上 PBXTargetDependency，指向 UI Test target —— 错的，反过来
# UI Test target 依赖主 target
test_target.add_dependency(app_target)

# 5. 在 project root 上声明 attributes（TestTargetID 等）
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][test_target.uuid] = {
  'CreatedOnToolsVersion' => '26.1.1',
  'TestTargetID' => app_target.uuid,
  'ProvisioningStyle' => 'Automatic'
}

# 6. 同步 main scheme - 加入 UI Test
scheme_path = Xcodeproj::XCScheme.shared_data_dir(PROJECT_PATH) + "#{APP_TARGET_NAME}.xcscheme"
if File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new(scheme_path.to_s)
  testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  scheme.test_action.add_testable(testable)
  # 也加到 build action（确保 test 时也能编 UI Test target）
  build_action_entry = Xcodeproj::XCScheme::BuildAction::Entry.new(test_target)
  build_action_entry.build_for_archiving = false
  build_action_entry.build_for_profiling = false
  build_action_entry.build_for_running = false
  build_action_entry.build_for_analyzing = true
  build_action_entry.build_for_testing = true
  scheme.build_action.add_entry(build_action_entry)
  scheme.save_as(PROJECT_PATH, APP_TARGET_NAME, true)
  puts "[ok] Scheme '#{APP_TARGET_NAME}' updated to include UI Test."
else
  puts "[warn] Shared scheme not found at #{scheme_path}; will rely on auto-generated scheme."
end

project.save
puts "[ok] UI Test target '#{TEST_TARGET_NAME}' added."
puts "      bundle id: #{TEST_BUNDLE_ID}"
puts "      sources:  #{TEST_TARGET_NAME}/MiniCPMVDemoUITests.swift"
