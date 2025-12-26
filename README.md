# ABPlayer

ABPlayer is a macOS local audio player designed specifically for language learners. Built on a modern Swift tech stack, it focuses on efficient **A-B looping**, **sentence-by-sentence intensive listening**, and **practice time statistics**.

The project deeply integrates [WhisperKit](https://github.com/argmaxinc/WhisperKit), supporting completely offline on-device AI speech-to-text, automatically generating timestamped subtitles to turn any audio material into listening study material.

<video src="Docs/videos/demo.mp4" controls="controls" style="max-width: 100%;"></video>

## ✨ Core Features

* **🎧 Smart Loop**:
* Millisecond-precision A-B loop control.
* Supports saving loop segments and quick jumping within the list.
* Keyboard shortcut-driven efficient interaction.


* **🤖 AI Transcription (Offline)**:
* Based on CoreML Whisper models; no internet connection required, protecting your privacy.
* Automatically generates timestamped subtitles; supports clicking subtitles to jump playback.


* **📂 Smart File Management**:
* Supports folder import, automatically associating audio, subtitles (.srt/.vtt), and PDF documents with the same name.
* Utilizes the Security-Scoped Bookmarks mechanism to automatically restore playback progress and file access permissions upon restart.


* **📊 Practice Tracking**:
* Built-in session tracker that provides real-time statistics and persistence of your listening practice time.



## 📥 Installation & Usage

### Method 1: GitHub Release Download (Recommended)

1. Go to the [Releases Page](https://github.com/sunset-valley/ABPlayer/releases) and download the latest `ABPlayer.zip`.
2. Unzip the file and drag `ABPlayer.app` into your `/Applications` folder.

### Method 2: Manual Build

If you are familiar with the development environment, you can pull the source code and build it directly:

```bash
git clone https://github.com/sunset-valley/ABPlayer.git
cd ABPlayer
mise install  # Install environment dependencies (Swift, Tuist)
tuist generate # Generate Xcode project
# Then run in Xcode

```

### ⚠️ About macOS Security Warning (Gatekeeper)

Since this project has not yet undergone Apple Developer Notarization, macOS may intercept it upon first launch and prompt that it "cannot be opened" or "cannot verify the developer."

**Solution**:

1. Attempt to run `ABPlayer.app` and click **"OK"** to close the interception popup.
2. Open **System Settings** -> **Privacy & Security**.
3. Scroll down to the "Security" section on the right, where you will see a message saying "ABPlayer was blocked...".
4. Click the **"Open Anyway"** button on the right.
5. Enter your password in the confirmation dialog (if required), then click **"Open"**.

*Tip: Once authorized, you can open the app directly in the future.*

Alternatively, execute the following command in the terminal to completely remove the quarantine attributes (this not only bypasses the check but also fixes "damaged file" prompts):

```bash
sudo xattr -cr /Applications/ABPlayer.app

```

## ⌨️ Shortcuts

To improve practice efficiency, the following shortcuts are recommended (default configuration):

| Action | Shortcut |
| --- | --- |
| **Play / Pause** | `Space` or `Option + Space` |
| **Set Point A** | `Option + X` |
| **Set Point B** | `Option + C` |
| **Clear Loop** | `Option + V` |
| **Save Segment** | `Option + B` |
| **Previous Segment** | `Option + ←` |
| **Next Segment** | `Option + →` |
| **Rewind 5s / Forward 10s** | `Option + F` / `Option + G` |

## 🛠️ Tech Stack

This project utilizes the latest Apple development tech stack:

* **Language**: Swift 6.2
* **UI Framework**: SwiftUI (NavigationSplitView, Observation)
* **Persistence**: SwiftData
* **Project Management**: [Tuist](https://tuist.io/)
* **AI Engine**: WhisperKit (CoreML)
* **CI/CD**: GitHub Actions + Custom Scripts

## 🤝 Contributing

You are very welcome to participate in the development of ABPlayer!

### Environment Preparation

This project uses `mise` and `tuist` to manage the environment and project files, ensuring consistency across all developers.

1. **Install Mise** (if you haven't already):
```bash
curl https://mise.run | sh

```


2. **Install Dependencies**:
Run the following in the project root directory:
```bash
mise install

```


This will automatically install the specified version of Tuist.

### Development Workflow

1. **Fork** this repository.
2. Generate the Xcode project:
```bash
tuist install && tuist generate

```


3. Open `ABPlayer.xcworkspace` for development.
4. Before submitting code, please refer to the code style guidelines in `AGENTS.md`.
5. Submit a Pull Request.

## 📄 License

This project is open-sourced under the **MIT License**.
