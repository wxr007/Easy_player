# Easy Player

一个功能强大的视频播放器，支持字幕编辑、横屏模式和字幕导出功能。

## 功能特点

- 📹 视频播放：支持各种视频格式的播放
- 📝 字幕支持：内置字幕解析和显示功能
- ✏️ 字幕编辑：可视化编辑字幕内容和时间轴
- 🔄 横屏模式：自动适配横屏布局，播放器在左侧，字幕列表在右侧
- 📤 字幕导出：将编辑后的字幕导出为 SRT 格式文件
- 🎯 目标模式：精确控制视频播放位置
- 🔧 设置菜单：弹出式设置菜单，方便快速调整播放器设置

## 技术栈

- **框架**：Flutter
- **状态管理**：Provider
- **视频播放**：video_player + chewie
- **文件处理**：path_provider + file_picker
- **权限管理**：permission_handler
- **存储**：shared_preferences
- **缩略图**：video_thumbnail

## 项目结构

```
lib/
├── models/           # 数据模型
│   ├── subtitle_item.dart  # 字幕项模型
│   └── video_item.dart     # 视频项模型
├── screens/          # 界面
│   ├── home_screen.dart          # 视频列表页面
│   ├── player_screen.dart        # 视频播放主界面
│   ├── player_subtitle_edit.dart # 字幕编辑窗口
│   ├── player_subtitle_list.dart # 字幕列表
│   └── player_progress_bar.dart  # 播放器工具栏
├── stores/           # 状态管理
│   └── video_store.dart          # 视频数据存储
├── theme/            # 主题
│   └── app_theme.dart            # 应用主题
├── utils/            # 工具类
│   └── subtitle_parser.dart      # 字幕解析和导出
└── main.dart         # 应用入口
```

## 安装和运行

### 前提条件

- Flutter SDK (^3.5.0)
- Dart SDK (^3.5.0)
- Android Studio 或 Visual Studio Code

### 安装步骤

1. 克隆项目

```bash
git clone https://github.com/yourusername/easy_player.git
cd easy_player
```

2. 安装依赖

```bash
flutter pub get
```

3. 运行项目

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web
flutter run -d web
```

## 使用说明

### 视频播放

1. 打开应用后，在首页选择视频文件
2. 点击视频缩略图开始播放
3. 使用底部工具栏控制播放、暂停、全屏等操作

### 字幕功能

1. **添加字幕**：点击工具栏中的字幕图标，选择字幕文件
2. **编辑字幕**：点击设置菜单，开启字幕编辑模式，然后点击字幕列表中的字幕项进行编辑
3. **导出字幕**：在字幕编辑模式下，点击工具栏中的导出图标，将字幕导出为 SRT 文件

### 横屏模式

- 自动适配横屏布局
- 横屏时播放器在左侧，字幕列表和工具栏在右侧
- 退出全屏时保持当前屏幕方向

### 目标模式

- 点击工具栏中的目标图标进入目标模式
- 精确控制视频播放位置

## 核心功能实现

### 字幕编辑

字幕编辑窗口采用底部抽屉式布局，支持：
- 编辑字幕内容
- 调整开始和结束时间
- 预览播放调整后的字幕片段

### 横屏布局

横屏时采用左右分栏布局：
- 左侧：视频播放器
- 右侧：字幕列表和工具栏

### 字幕导出

支持将字幕列表导出为标准 SRT 格式文件，方便在其他播放器中使用。

## 界面展示

### 首页

![首页](https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Flutter%20video%20player%20app%20home%20screen%20with%20video%20thumbnails%20grid&image_size=square_hd)

### 播放界面

![播放界面](https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Flutter%20video%20player%20interface%20with%20subtitle%20list%20on%20the%20right&image_size=landscape_16_9)

### 字幕编辑

![字幕编辑](https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Flutter%20subtitle%20edit%20bottom%20sheet%20with%20text%20input%20and%20time%20adjustment&image_size=portrait_4_3)

## 权限说明

- **存储权限**：用于读取视频和字幕文件
- **媒体库权限**：用于访问设备中的视频文件

## 平台支持

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 开发说明

### 代码风格

- 遵循 Flutter 官方代码风格
- 使用 Provider 进行状态管理
- 采用模块化设计，代码结构清晰

### 测试

```bash
flutter test
```

### 构建

```bash
# Android
flutter build apk

# iOS
flutter build ios

# Web
flutter build web
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 联系方式

- 项目地址：https://github.com/yourusername/easy_player
- 作者：Your Name
- 邮箱：your.email@example.com

---

**享受你的视频播放体验！** 🎬