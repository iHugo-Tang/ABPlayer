# ABPlayer 数据模型 ER 图

> [!NOTE]
> 本项目使用 **SwiftData** 而非 CoreData，但两者概念相似。本文档展示所有数据模型实体及其关系。

## 核心实体概览

ABPlayer 共有 **6 个数据模型实体**：

1. **AudioFile** - 音频文件
2. **LoopSegment** - 循环片段
3. **Folder** - 文件夹
4. **SubtitleFile** - 字幕文件
5. **Transcription** - 转录数据
6. **ListeningSession** - 收听会话

---

## 完整 ER 图

```mermaid
erDiagram
    AudioFile ||--o{ LoopSegment : "包含多个"
    AudioFile }o--|| Folder : "属于"
    AudioFile ||--o| SubtitleFile : "关联"
    AudioFile ||--o| Transcription : "有转录（通过ID）"
    AudioFile ||--o| PlaybackRecord : "有播放记录"
    Folder ||--o{ Folder : "包含子文件夹"
    Folder ||--o{ AudioFile : "包含多个"
    
    AudioFile {
        UUID id PK
        String displayName "显示名称"
        Data bookmarkData "文件bookmark"
        Date createdAt "创建时间"
        Data pdfBookmarkData "PDF文件bookmark"
        Double cachedDuration "缓存的音频时长"
        Bool hasTranscription "是否有SRT文件"
    }
    
    PlaybackRecord {
        UUID id PK
        Date lastPlayedAt "上次播放时间"
        Int completionCount "播放完成次数"
        Double currentPosition "当前播放位置"
        UUID audioFileId FK "关联的音频文件"
    }
    
    LoopSegment {
        UUID id PK
        String label "标签"
        Double startTime "开始时间"
        Double endTime "结束时间"
        Int index "索引"
        Date createdAt "创建时间"
        UUID audioFileId FK "关联的音频文件"
    }
    
    Folder {
        UUID id PK
        String name "文件夹名称"
        Date createdAt "创建时间"
        UUID parentId FK "父文件夹"
    }
    
    SubtitleFile {
        UUID id PK
        String displayName "显示名称"
        Data bookmarkData "文件bookmark"
        Date createdAt "创建时间"
        Data cachedCuesData "缓存的字幕数据JSON"
        UUID audioFileId FK "关联的音频文件"
    }
    
    Transcription {
        UUID id PK
        String audioFileId "音频文件ID（字符串）"
        String audioFileName "音频文件名"
        Data cachedCuesData "缓存的字幕数据JSON"
        Date createdAt "创建时间"
        String modelUsed "使用的模型"
        String language "检测到的语言"
    }
    
    ListeningSession {
        UUID id PK
        Date startedAt "开始时间"
        Double durationSeconds "持续时长（秒）"
        Date endedAt "结束时间"
    }
```

---

## 实体详细说明

### 1️⃣ AudioFile（音频文件）

**用途**：存储音频文件的核心信息和元数据

**关键字段**：
- `id`: 唯一标识符
- `displayName`: 显示名称
- `bookmarkData`: 安全作用域 bookmark，用于访问沙盒外文件
- `bookmarkData`: 安全作用域 bookmark，用于访问沙盒外文件
- `cachedDuration`: 缓存音频时长，避免重复读取
- `hasTranscription`: 标记是否存在 SRT 转录文件
- `pdfBookmarkData`: 关联的 PDF 文件

**关系**：
- 一对多：`segments` - 一个音频文件可以有多个循环片段
- 多对一：`folder` - 归属于某个文件夹
- 一对一：`subtitleFile` - 可关联一个字幕文件
- 一对一：`playbackRecord` - 关联播放记录

---

### 2️⃣ LoopSegment（循环片段）

**用途**：存储音频文件的 AB 循环片段

**关键字段**：
- `label`: 片段标签/名称
- `startTime`, `endTime`: 片段时间范围（秒）
- `index`: 排序索引

**关系**：
- 多对一：`audioFile` - 每个片段属于一个音频文件

---

### 3️⃣ Folder（文件夹）

**用途**：组织音频文件的层级结构

**关键字段**：
- `name`: 文件夹名称
- `sortedAudioFiles`: 计算属性，按文件名排序的音频列表

**关系**：
- 自引用：`parent` / `subfolders` - 支持多级文件夹嵌套
- 一对多：`audioFiles` - 包含多个音频文件

> [!TIP]
> `sortedAudioFiles` 用于保证播放顺序的一致性

---

### 4️⃣ SubtitleFile（字幕文件）

**用途**：存储外部导入的字幕文件（SRT/VTT）

**关键字段**：
- `bookmarkData`: 字幕文件的 bookmark
- `cachedCuesData`: 解析后的字幕数据（JSON 格式）
- `cues`: 计算属性，返回 `[SubtitleCue]`

**关系**：
- 一对一：`audioFile` - 关联到一个音频文件

**相关类型**：
```swift
struct SubtitleCue: Codable {
    let id: UUID
    let startTime: Double
    let endTime: Double
    let text: String
}
```

---

### 5️⃣ Transcription（转录数据）

**用途**：存储 AI 转录生成的字幕数据（历史记录）

> [!IMPORTANT]
> **注意**：Transcription 作为历史缓存，实际字幕优先从 SRT 文件加载

**关键字段**：
- `audioFileId`: 音频文件 UUID（字符串格式）
- `audioFileName`: 音频文件名（用于显示）
- `cachedCuesData`: 转录结果的字幕数据
- `modelUsed`: 使用的 WhisperKit 模型（如 "distil-large-v3"）
- `language`: 检测到的语言

**关系**：
- 通过 `audioFileId` 字符串关联 `AudioFile`（非正式外键）

**逻辑关系**：
```
AudioFile.id.uuidString === Transcription.audioFileId
```

---

### 6️⃣ ListeningSession（收听会话）

**用途**：追踪用户的收听时长会话

**关键字段**：
- `startedAt`: 会话开始时间
- `durationSeconds`: 累计收听时长
- `endedAt`: 会话结束时间（可选）

**关系**：
- 独立实体，不直接关联其他模型
- 由 `SessionTracker` 服务管理

> [!NOTE]
> 这是一个统计性实体，用于追踪总体使用时长

---

## 关系类型总结

### 7️⃣ PlaybackRecord（播放记录）

**用途**：存储音频文件的播放进度和统计信息

**关键字段**：
- `currentPosition`: 当前播放进度（秒）
- `completionCount`: 完整播放次数
- `lastPlayedAt`: 上次播放时间戳

**关系**：
- 一对一：`audioFile` - 关联到一个音频文件（级联删除）

---

## 关系类型总结

| 关系 | 类型 | 说明 |
|------|------|------|
| `AudioFile` ↔ `LoopSegment` | 1:N | 一个音频可有多个循环片段 |
| `AudioFile` ↔ `Folder` | N:1 | 多个音频属于一个文件夹 |
| `AudioFile` ↔ `SubtitleFile` | 1:1 | 一个音频关联一个字幕 |
| `AudioFile` ↔ `Transcription` | 1:N（逻辑） | 通过 UUID 字符串关联 |
| `AudioFile` ↔ `PlaybackRecord` | 1:1 | 播放进度记录（级联删除）|
| `Folder` ↔ `Folder` | 自引用 | 支持多级嵌套 |
| `ListeningSession` | 独立 | 无直接关系 |

---

## 数据存储策略

### 外部存储（`@Attribute(.externalStorage)`）

以下大型数据使用外部存储优化：
- `AudioFile.bookmarkData`
- `AudioFile.pdfBookmarkData`
- `SubtitleFile.bookmarkData`
- `SubtitleFile.cachedCuesData`
- `Transcription.cachedCuesData`

### 字幕加载优先级

```mermaid
graph TD
    A[加载字幕] --> B{SRT 文件存在?}
    B -->|是| C[从 SRT 文件加载]
    B -->|否| D{数据库有缓存?}
    D -->|是| E[从 Transcription 加载]
    D -->|否| F[显示无字幕]
    
    style C fill:#90EE90
    style E fill:#FFD700
    style F fill:#FFB6C1
```

---

## 设计亮点

1. **安全作用域访问**：使用 `bookmarkData` 持久化沙盒外文件访问权限
2. **性能优化**：
   - `cachedDuration` 避免重复读取音频时长
   - `hasTranscription` 避免文件系统查询
   - 外部存储优化大型数据
3. **灵活的字幕系统**：
   - 支持外部字幕文件（SubtitleFile）
   - 支持 AI 转录（Transcription）
   - SRT 文件优先，数据库作为备份
4. **层级组织**：Folder 自引用支持无限层级

---

## 相关文件

- [AudioModels.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/AudioModels.swift) - AudioFile & LoopSegment
- [Folder.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/Folder.swift) - Folder
- [SubtitleFile.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/SubtitleFile.swift) - SubtitleFile & SubtitleCue
- [Transcription.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Models/Transcription.swift) - Transcription
- [SessionTracker.swift](file:///Volumes/Data/Code/mine/ABPlayer/ABPlayer/Sources/Services/SessionTracker.swift) - ListeningSession
