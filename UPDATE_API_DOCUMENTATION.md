# Android 更新机制说明文档

## 概述
项目的 Android 更新提示框位于 `lib/home/homeview/view.dart` 文件中，已经支持多下载源功能。

## API 数据格式

### 新格式（推荐）- 支持多下载源

```json
{
  "is_latest": false,
  "latest_version": "1.3.0",
  "description": "更新说明...",
  "is_forced": false,
  "downloadSources": [
    {
      "name": "夸克网盘",
      "url": "https://pan.quark.cn/s/b412107eeaa6",
      "priority": 1,
      "description": "国内下载，速度较快"
    },
    {
      "name": "GitHub Release",
      "url": "https://github.com/cc2562/superhut/releases/latest",
      "priority": 2,
      "description": "官方仓库，可能需要科学上网"
    }
  ],
  "download_url": "https://pan.quark.cn/s/b412107eeaa6"
}
```

### 旧格式（兼容）- 单一下载源

```json
{
  "is_latest": false,
  "latest_version": "1.3.0",
  "description": "更新说明...",
  "is_forced": false,
  "download_url": "https://pan.quark.cn/s/b412107eeaa6"
}
```

## 字段说明

### 基础字段
- `is_latest` (boolean): 当前版本是否为最新版本
- `latest_version` (string): 最新版本号
- `description` (string): 更新说明
- `is_forced` (boolean): 是否强制更新

### 下载源字段

#### downloadSources (array, 可选)
下载源数组，每个元素包含：
- `name` (string, 必填): 下载源名称，如 "夸克网盘"、"GitHub Release"
- `url` (string, 必填): 下载链接
- `priority` (number, 可选): 优先级，数字越小优先级越高，默认 999
- `description` (string, 可选): 下载源描述

#### download_url (string, 可选)
兼容旧格式的单一下载链接。如果没有提供 `downloadSources`，会自动转换为下载源格式。

## 前端行为

### 1. 单一下载源
当只有一个下载源时（无论是新格式还是旧格式），更新弹窗显示：
- 更新说明
- "稍后更新" 按钮（非强制更新时）
- "立即更新" 按钮

### 2. 多个下载源
当有多个下载源时，更新弹窗显示：
- 更新说明
- 提示 "选择下载源："
- "稍后更新" 按钮（非强制更新时）
- "选择下载源" 按钮

点击 "选择下载源" 后，会弹出第二个对话框，显示所有下载源的列表（按 priority 排序）：
- 每个下载源显示为一个 ListTile
- 包含图标、名称和描述（如果有）
- 点击任意下载源即可跳转到对应链接

## 后端 API 修改建议

修改 `https://super.ccrice.com/api/check_version.php` 返回格式：

```php
<?php
// 示例代码
$response = [
    'is_latest' => false,
    'latest_version' => '1.3.0',
    'description' => '更新说明...',
    'is_forced' => false,
    'downloadSources' => [
        [
            'name' => '夸克网盘',
            'url' => 'https://pan.quark.cn/s/b412107eeaa6',
            'priority' => 1,
            'description' => '国内下载，速度较快'
        ],
        [
            'name' => 'GitHub Release',
            'url' => 'https://github.com/cc2562/superhut/releases/latest',
            'priority' => 2,
            'description' => '官方仓库，可能需要科学上网'
        ]
    ],
    'download_url' => 'https://pan.quark.cn/s/b412107eeaa6' // 保留兼容性
];

header('Content-Type: application/json');
echo json_encode($response);
?>
```

## 优势

1. **向后兼容**：保留 `download_url` 字段，旧版本 App 仍可正常使用
2. **灵活扩展**：可以随时添加新的下载源，如阿里云盘、123网盘等
3. **优先级控制**：通过 `priority` 字段控制显示顺序
4. **用户友好**：用户可以根据自己的网络环境选择最快的下载源

## 测试建议

1. 测试旧格式 API（只有 download_url）
2. 测试新格式 API（只有 downloadSources，单个源）
3. 测试新格式 API（downloadSources，多个源）
4. 测试强制更新场景
5. 测试非强制更新场景