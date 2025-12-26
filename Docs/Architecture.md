# ABPlayer 架构文档

ABPlayer 是一款专为语言学习者设计的 macOS 本地音频播放器，提供高效的 A-B 复读、逐句精听和练习时间统计功能。

---

## 目录
1. [系统架构概览](#系统架构概览)
2. [技术栈](#技术栈)
3. [项目结构](#项目结构)
4. [数据模型层](#数据模型层)
5. [服务层](#服务层)
6. [视图层](#视图层)
7. [业务逻辑详解](#业务逻辑详解)
8. [数据流](#数据流)
9. [测试覆盖](#测试覆盖)

---

## 系统架构概览

```mermaid
graph TB
    subgraph "Application Layer"
        APP[ABPlayerApp.swift<br/>应用入口]
    end
    
    subgraph "View Layer"
        MSV[MainSplitView<br/>主布局]
        PV[PlayerView<br/>播放控制]
        FNV[FolderNavigationView<br/>文件导航]
        CPV[ContentPanelView<br/>内容面板]
        TV[TranscriptionView<br/>转录视图]
        SV[SubtitleView<br/>字幕视图]
        PDFV[PDFContentView<br/>PDF视图]
        SetV[SettingsView<br/>设置]
    end
    
    subgraph "Service Layer"
        APM[AudioPlayerManager<br/>音频播放引擎]
        ST[SessionTracker<br/>会话追踪]
        TM[TranscriptionManager<br/>AI转录服务]
        FI[FolderImporter<br/>文件夹导入]
        TS[TranscriptionSettings<br/>转录设置]
    end
    
    subgraph "Model Layer / SwiftData"
        AF[AudioFile<br/>音频文件]
        LS[LoopSegment<br/>AB段落]
        FD[Folder<br/>文件夹]
        SF[SubtitleFile<br/>字幕文件]
        TR[Transcription<br/>转录缓存]
        LSE[ListeningSession<br/>练习会话]
    end
    
    subgraph "External Dependencies"
        WK[WhisperKit<br/>AI语音识别]
        AVF[AVFoundation<br/>音频播放]
        KS[KeyboardShortcuts<br/>快捷键]
        SEN[Sentry<br/>错误监控]
    end
    
    APP --> MSV
    APP --> APM
    APP --> ST
    APP --> TM
    APP --> TS
    
    MSV --> PV
    MSV --> FNV
    MSV --> CPV
    
    CPV --> TV
    CPV --> SV
    CPV --> PDFV
    
    PV --> APM
    PV --> ST
    TV --> TM
    TV --> TS
    FNV --> FI
    
    APM --> AVF
    TM --> WK
    APP --> KS
    APP --> SEN
    
    APM --> AF
    APM --> LS
    ST --> LSE
    FI --> AF
    FI --> FD
    FI --> SF
    TM --> TR
```

---

## 技术栈

| 分类 | 技术 | 说明 |
|------|------|------|
| **语言** | Swift 6.2 | 使用最新 Swift 并发特性 |
| **UI 框架** | SwiftUI | NavigationSplitView, @Observable |
| **数据持久化** | SwiftData | @Model 宏，自动保存 |
| **项目管理** | [Tuist](https://tuist.io/) | 模块化项目生成 |
| **AI 引擎** | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | CoreML 离线语音识别 |
| **快捷键** | KeyboardShortcuts | 全局热键支持 |
| **错误监控** | Sentry | 生产环境错误追踪 |

---

## 项目结构

```text
ABPlayer/
├── ABPlayer/
│   ├── Sources/
│   │   ├── ABPlayerApp.swift        # 应用入口
│   │   ├── Design/                  # 设计系统
│   │   │   ├── Theme.swift          # 主题颜色
│   │   │   └── Typography.swift     # 字体样式
│   │   ├── Models/                  # 数据模型
│   │   │   ├── AudioModels.swift    # AudioFile, LoopSegment
│   │   │   ├── Folder.swift         # 文件夹模型
│   │   │   ├── SubtitleFile.swift   # 字幕文件+解析器
│   │   │   └── Transcription.swift  # 转录缓存
│   │   ├── Services/                # 业务服务
│   │   │   ├── AudioPlayerManager.swift    # 播放引擎
│   │   │   ├── SessionTracker.swift        # 会话追踪
│   │   │   ├── TranscriptionManager.swift  # AI转录
│   │   │   ├── TranscriptionSettings.swift # 转录设置
│   │   │   ├── FolderImporter.swift        # 文件夹导入
│   │   │   └── ShortcutNames.swift         # 快捷键定义
│   │   └── Views/                   # 视图组件
│   │       ├── MainSplitView.swift        # 主分栏视图
│   │       ├── PlayerView.swift           # 播放器视图
│   │       ├── FolderNavigationView.swift # 文件夹导航
│   │       ├── ContentPanelView.swift     # 内容面板
│   │       ├── TranscriptionView.swift    # AI转录视图
│   │       ├── SubtitleView.swift         # 字幕列表
│   │       ├── PDFContentView.swift       # PDF阅读
│   │       ├── SettingsView.swift         # 设置界面
│   │       └── Components/                # 通用组件
│   ├── Tests/                       # 单元测试
│   │   ├── ABPlayerTests.swift      # 播放器测试
│   │   └── TranscriptionTests.swift # 转录测试
│   └── Resources/                   # 资源文件
├── Docs/                            # 文档
├── scripts/                         # 构建脚本
└── Project.swift                    # Tuist 项目配置
```

---

## 数据模型层

### 实体关系图

```mermaid
erDiagram
    Folder ||--o{ AudioFile : contains
    Folder ||--o{ Folder : subfolders
    AudioFile ||--o{ LoopSegment : segments
    AudioFile ||--o| SubtitleFile : subtitleFile
    AudioFile }|--|| Transcription : "cached by audioFileId"
    
    Folder {
        UUID id PK
        String name
        Date createdAt
        Folder parent FK
    }
    
    AudioFile {
        UUID id PK
        String displayName
        Data bookmarkData
        Date createdAt
        Double lastPlaybackTime
        Double cachedDuration
        Data pdfBookmarkData
    }
    
    LoopSegment {
        UUID id PK
        String label
        Double startTime
        Double endTime
        Int index
        Date createdAt
    }
    
    SubtitleFile {
        UUID id PK
        String displayName
        Data bookmarkData
        Date createdAt
        Data cachedCuesData
    }
    
    Transcription {
        UUID id PK
        String audioFileId
        String audioFileName
        Date createdAt
        String modelUsed
        String language
        Data cachedCuesData
    }
    
    ListeningSession {
        UUID id PK
        Date startedAt
        Double durationSeconds
        Date endedAt
    }
```

### 模型详解

| 模型 | 文件路径 | 说明 |
|------|----------|------|
| **AudioFile** | [AudioModels.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/AudioModels.swift#L4-L57) | 音频文件，存储 Security-Scoped Bookmark |
| **LoopSegment** | [AudioModels.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/AudioModels.swift#L59-L87) | A-B 循环段落，关联到 AudioFile |
| **Folder** | [Folder.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/Folder.swift) | 文件夹，支持嵌套结构 |
| **SubtitleFile** | [SubtitleFile.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/SubtitleFile.swift#L19-L59) | 字幕文件 (SRT/VTT)，含解析器 |
| **Transcription** | [Transcription.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/Transcription.swift) | AI 转录缓存 |
| **ListeningSession** | [SessionTracker.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift#L5-L23) | 练习时间会话 |

---

## 服务层

### 服务依赖图

```mermaid
graph LR
    subgraph "核心服务"
        APM[AudioPlayerManager]
        ST[SessionTracker]
    end
    
    subgraph "AI 服务"
        TM[TranscriptionManager]
        TS[TranscriptionSettings]
    end
    
    subgraph "文件服务"
        FI[FolderImporter]
    end
    
    APM -->|"addListeningTime()"| ST
    TM -->|"使用设置"| TS
    FI -->|"解析字幕"| SubtitleParser
    TM -->|"WhisperKit"| AIEngine
```

### 服务详解

#### 1. AudioPlayerManager

**路径**: [AudioPlayerManager.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift)

**职责**:
- 音频播放控制 (播放/暂停/跳转)
- A-B 循环管理 (设置点 A/B、循环检测)
- 段落管理 (保存/删除/导航)
- 播放进度持久化

**关键方法**:

| 方法 | 行号 | 说明 |
|------|------|------|
| `load(audioFile:fromStart:)` | [L93-155](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift#L93-L155) | 加载音频文件 |
| `togglePlayPause()` | - | 播放/暂停 |
| `setPointA()` / `setPointB()` | - | 设置 A/B 点 |
| `saveCurrentSegment()` | [L274-296](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift#L274-L296) | 保存当前 AB 段落 |
| `selectPreviousSegment()` / `selectNextSegment()` | [L330-365](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift#L330-L365) | 段落导航 |

---

#### 2. SessionTracker

**路径**: [SessionTracker.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift)

**职责**:
- 追踪练习时间
- 自动创建/结束会话
- 定期持久化 (每5秒)

**关键方法**:

| 方法 | 行号 | 说明 |
|------|------|------|
| `startSessionIfNeeded()` | [L39-47](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift#L39-L47) | 开始新会话 |
| `addListeningTime(_:)` | [L49-73](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift#L49-L73) | 累加练习时间 |
| `endSessionIfIdle()` | [L112-133](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift#L112-L133) | 结束会话 |

---

#### 3. TranscriptionManager

**路径**: [TranscriptionManager.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/TranscriptionManager.swift)

**职责**:
- 加载 WhisperKit 模型
- 执行音频转录
- 管理转录状态

**状态机**:

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> downloading: 下载模型
    idle --> loading: 加载模型
    downloading --> loading: 下载完成
    loading --> idle: 加载完成
    idle --> transcribing: 开始转录
    transcribing --> completed: 转录成功
    transcribing --> failed: 转录失败
    completed --> idle: reset()
    failed --> idle: reset()
```

---

#### 4. FolderImporter

**路径**: [FolderImporter.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/FolderImporter.swift)

**职责**:
- 递归导入文件夹
- 自动配对音频与字幕/PDF
- 创建 Security-Scoped Bookmarks

**自动配对规则**:
- 音频扩展名: `mp3`, `m4a`, `wav`, `aac`
- 字幕扩展名: `srt`, `vtt`
- 同名文件自动关联

---

## 视图层

### 视图层次结构

```mermaid
graph TD
    APP[ABPlayerApp] --> WG[WindowGroup]
    WG --> MSV[MainSplitView]
    
    MSV --> |Sidebar| FNV[FolderNavigationView]
    MSV --> |Detail| PV[PlayerView]
    
    PV --> |HStack| PS[playerSection]
    PV --> |HStack| CPV[ContentPanelView]
    
    PS --> header
    PS --> progressSection
    PS --> loopControls
    PS --> segmentsSection
    
    CPV --> TabView
    TabView --> TV[TranscriptionView]
    TabView --> SV[SubtitleView]
    TabView --> PDFV[PDFContentView]
    
    APP --> |Settings Window| SetV[SettingsView]
```

### 视图详解

| 视图 | 文件路径 | 说明 |
|------|----------|------|
| **MainSplitView** | [MainSplitView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/MainSplitView.swift) | NavigationSplitView 主布局 |
| **PlayerView** | [PlayerView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/PlayerView.swift) | 播放控制、进度条、AB段落 |
| **FolderNavigationView** | [FolderNavigationView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/FolderNavigationView.swift) | 侧边栏文件夹/文件导航 |
| **ContentPanelView** | [ContentPanelView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/ContentPanelView.swift) | 右侧内容面板容器 |
| **TranscriptionView** | [TranscriptionView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/TranscriptionView.swift) | AI 转录界面 |
| **SubtitleView** | [SubtitleView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/SubtitleView.swift) | 字幕列表显示 |
| **PDFContentView** | [PDFContentView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/PDFContentView.swift) | PDF 文档阅读 |
| **SettingsView** | [SettingsView.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Views/SettingsView.swift) | 应用设置界面 |

---

## 业务逻辑详解

### 1. A-B 循环播放

**文件**: [AudioPlayerManager.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift)

**流程**:

```mermaid
sequenceDiagram
    participant User
    participant PlayerView
    participant AudioPlayerManager
    participant AVPlayer
    
    User->>PlayerView: 点击 "Set A"
    PlayerView->>AudioPlayerManager: setPointA()
    AudioPlayerManager->>AudioPlayerManager: pointA = currentTime
    
    User->>PlayerView: 点击 "Set B"
    PlayerView->>AudioPlayerManager: setPointB()
    AudioPlayerManager->>AudioPlayerManager: pointB = currentTime
    AudioPlayerManager->>AudioPlayerManager: isLooping = true
    
    loop 播放循环
        AVPlayer->>AudioPlayerManager: onTimeUpdate(seconds)
        AudioPlayerManager->>AudioPlayerManager: handleLoopCheck(seconds)
        alt seconds >= pointB
            AudioPlayerManager->>AVPlayer: seek(to: pointA)
        end
    end
```

**核心逻辑** ([L367-377](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift#L367-L377)):
```swift
private func handleLoopCheck(_ seconds: Double) {
    guard isLooping, let pointA, let pointB else { return }
    if seconds >= pointB {
        seek(to: pointA)
    }
}
```

---

### 2. 段落保存与导航

**文件**: [AudioPlayerManager.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/AudioPlayerManager.swift)

**保存流程**:
1. 验证 `pointA` 和 `pointB` 有效 (B > A)
2. 检查是否存在重复段落
3. 创建 `LoopSegment` 并关联到 `AudioFile`
4. 自动设置标签 (Segment 1, 2, 3...)

**导航流程**:
```mermaid
graph LR
    A[当前段落] -->|"Option + ←"| B[上一段落]
    A -->|"Option + →"| C[下一段落]
    B --> D[应用段落]
    C --> D
    D --> E[设置 pointA/pointB]
    D --> F[跳转到 pointA]
```

---

### 3. 练习时间追踪

**文件**: [SessionTracker.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift)

**流程**:

```mermaid
sequenceDiagram
    participant AudioPlayerManager
    participant SessionTracker
    participant SwiftData
    
    AudioPlayerManager->>SessionTracker: addListeningTime(0.03)
    
    alt 无当前会话
        SessionTracker->>SwiftData: insert(ListeningSession)
        SessionTracker->>SessionTracker: currentSession = session
    end
    
    SessionTracker->>SessionTracker: session.durationSeconds += delta
    
    alt 超过5秒未保存
        SessionTracker->>SwiftData: save()
    end
```

---

### 4. AI 转录

**文件**: [TranscriptionManager.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/TranscriptionManager.swift)

**流程**:

```mermaid
sequenceDiagram
    participant User
    participant TranscriptionView
    participant TranscriptionManager
    participant WhisperKit
    participant SwiftData
    
    User->>TranscriptionView: 点击转录按钮
    TranscriptionView->>TranscriptionManager: transcribe(audioURL, settings)
    
    alt 模型未加载
        TranscriptionManager->>WhisperKit: loadModel(modelName)
        TranscriptionManager->>TranscriptionManager: state = .loading
    end
    
    TranscriptionManager->>TranscriptionManager: state = .transcribing
    TranscriptionManager->>WhisperKit: transcribe(audioPath, options)
    WhisperKit-->>TranscriptionManager: [TranscriptionResult]
    
    TranscriptionManager->>TranscriptionManager: 转换为 [SubtitleCue]
    TranscriptionManager->>SwiftData: insert(Transcription)
    TranscriptionManager->>TranscriptionManager: state = .completed
    
    TranscriptionManager-->>TranscriptionView: [SubtitleCue]
```

---

### 5. 文件夹导入

**文件**: [FolderImporter.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/FolderImporter.swift)

**流程**:

```mermaid
graph TD
    A[用户选择文件夹] --> B[获取 Security-Scoped Access]
    B --> C{遍历目录}
    
    C --> D[音频文件]
    C --> E[字幕文件]
    C --> F[PDF 文件]
    C --> G[子文件夹]
    
    D --> H[创建 AudioFile]
    H --> I{存在同名字幕?}
    I -->|是| J[创建 SubtitleFile 并关联]
    I -->|否| K{存在同名 PDF?}
    K -->|是| L[关联 PDF bookmark]
    K -->|否| M[完成]
    
    G --> C
```

---

### 6. 键盘快捷键

**文件**: [ShortcutNames.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/ShortcutNames.swift), [ABPlayerApp.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/ABPlayerApp.swift#L33-L86)

| 快捷键 | 功能 | 注册位置 |
|--------|------|----------|
| `Space` / `Option+Space` | 播放/暂停 | ABPlayerApp L36-40 |
| `Option+X` | 设置 A 点 | ABPlayerApp L52-56 |
| `Option+C` | 设置 B 点 | ABPlayerApp L58-62 |
| `Option+V` | 清除循环 | ABPlayerApp L64-68 |
| `Option+B` | 保存段落 | ABPlayerApp L70-74 |
| `Option+←` | 上一段落 | ABPlayerApp L76-80 |
| `Option+→` | 下一段落 | ABPlayerApp L82-86 |
| `Option+F` | 后退 5 秒 | ABPlayerApp L42-46 |
| `Option+G` | 前进 10 秒 | ABPlayerApp L48-52 |

---

## 数据流

### 依赖注入

```mermaid
graph TD
    APP[ABPlayerApp.init] --> |创建| APM[AudioPlayerManager]
    APP --> |创建| ST[SessionTracker]
    APP --> |创建| TM[TranscriptionManager]
    APP --> |创建| TS[TranscriptionSettings]
    APP --> |创建| MC[ModelContainer]
    
    APP --> |".environment()"| MSV[MainSplitView]
    
    MSV --> |传递| PV[PlayerView]
    MSV --> |传递| FNV[FolderNavigationView]
    PV --> |传递| CPV[ContentPanelView]
    CPV --> |传递| TV[TranscriptionView]
```

### 状态更新流

```mermaid
graph LR
    subgraph "用户操作"
        A[点击播放]
        B[设置 A/B]
        C[选择文件]
    end
    
    subgraph "Service Layer"
        APM[AudioPlayerManager]
        ST[SessionTracker]
    end
    
    subgraph "SwiftData"
        AF[AudioFile]
        LS[LoopSegment]
        LSE[ListeningSession]
    end
    
    subgraph "View Layer"
        PV[PlayerView]
    end
    
    A --> APM
    APM --> |"@Observable"| PV
    APM --> |"addListeningTime"| ST
    ST --> LSE
    
    B --> APM
    APM --> LS
    
    C --> APM
    APM --> AF
```

---

## 测试覆盖

### 现有测试

| 测试文件 | 测试内容 |
|----------|----------|
| [ABPlayerTests.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Tests/ABPlayerTests.swift) | 循环索引、排序、选择同步 |
| [TranscriptionTests.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Tests/TranscriptionTests.swift) | 字幕编码、转录状态、设置管理 |

### 待添加测试

以下业务逻辑建议补充单元测试：

1. **A-B 循环逻辑测试**
   - `setPointA()` / `setPointB()` 边界条件
   - `handleLoopCheck()` 循环检测

2. **SessionTracker 测试**
   - 会话创建/结束
   - 时间累加准确性

3. **FolderImporter 测试**
   - 文件配对逻辑
   - 递归目录处理

4. **SubtitleParser 测试**
   - SRT 格式解析
   - VTT 格式解析
   - 时间戳解析
