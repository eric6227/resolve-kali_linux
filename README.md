# 在 Kali Linux 上容器化运行 DaVinci Resolve [Studio]（x86_64 + NVIDIA）
> [!NOTE]
> - 本项目基于 fat-tire/resolve 项目，针对 Kali Linux 宿主机修改。
> - 本项目已经在 Davinci Resolve Studio 版本和免费版 Davinci Resolve 上测试通过，软件功能正常。
> - 本项目仅在 nvidia 显卡上测试通过，AMD 显卡未测试，但肯定不会不兼容（Nvidia, F**K you!）。
> - 请勿使用盗版 Davinci Resolve Studio 安装包。使用盗版导致的问题请勿提交 Issue。

这是一个基于 [fat-tire/resolve](https://github.com/fat-tire/resolve) 项目、针对 **Kali Linux** 宿主机修改的版本。

原项目面向 Ubuntu / Debian / Mint / PopOS / RockyOS 等发行版；本仓库在此基础上做了针对 Kali Linux 的调整，其余原理、目录映射、环境变量、故障排查等与原版基本一致。

> **原版说明文档**：
> - 原始仓库 README：[fat-tire/resolve - README.md](https://github.com/fat-tire/resolve)
> - 本仓库内保留的原版完整说明：[README_ORIGIN.md](./README_ORIGIN.md)

## 这是什么

[DaVinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve/) 是 Blackmagic Design 推出的免费（及付费 Studio 版）非线性剪辑软件。它最初是为（现已停止维护的）CentOS 发行版设计的，在其他发行版上直接安装往往会有库兼容性问题。

本项目的思路是：**宿主机用 Kali Linux，通过容器（Podman / Docker，默认 podman）在 CentOS Stream / Rocky Linux 的 guest 环境中运行 DaVinci Resolve**，这样它就能运行在它“期望”的原生环境里，同时你的工程、素材、字体、配置等数据都通过 bind mount 保存在宿主机上，容器本身保持“一次性”（ephemeral）。

## 与 Kali Linux 相关的注意事项

- Kali 是 Debian 系发行版，安装容器工具链使用 `apt`。
- Kali 默认使用 root 用户、默认 shell 为 Zsh；本脚本在普通用户下运行即可，无需 root。
- NVIDIA 驱动的安装方式与 Ubuntu 不同（Kali 没有“软件与更新 → 附加驱动”界面），需要通过 Kali 官方仓库或 NVIDIA 官方 `.run` 包安装，详见下文步骤。
- 图形会话建议使用 X11（Xorg，默认的图形会话类型）。Kali 默认桌面通常是 Xfce（推荐选择的，自动安装默认的） / GNOME，理论上 Wayland 也能工作，但 X11 兼容性最稳。
- 中文字形使用宿主机字体；若系统没有 CJK 字体，可安装 `fonts-noto-cjk`。

## 运行环境要求

- x86_64 主机，内存建议 16GB 以上（Blackmagic Design 官方对 Studio 版建议 32GB）。
- 一块较新的 NVIDIA GPU（本项目使用 NVIDIA GPU 测试，但是如果不希望折腾驱动，建议使用 AMD GPU。显存建议 8GB 以上）。
- 已安装 Kali Linux（绝对建议使用普通用户而非 root 运行）。
- （可选）DaVinci Resolve Studio 的 USB 加密狗（Dongle。未测试）。
- （可选）DaVinci Resolve Speed Editor（仅 USB；蓝牙支持见原版 README。未测试）。
- （可选）激活码（Registration Code）支持。默认 bridge 网络允许容器访问互联网。

## 安装步骤（Kali Linux）

### 1. 安装 NVIDIA 驱动

> 如果是 AMD 显卡，无需这么麻烦，直接安装 AMD 的开源驱动即可。

首先安装驱动：
- 在英伟达官网下载驱动包，例如 `NVIDIA-Linux-x86_64-580.178.04.run`

> [!WARNING]
> 注意：必须使用高于 570 的驱动版本，否则达芬奇将无法运行。此处使用 580.178.04 版本。

 按下 `Ctrl + Alt + F3` 切换到文本模式，登录后执行以下命令：

```bash
cd <你的下载文件夹>
sudo ./NVIDIA-Linux-x86_64-580.178.04.run
```
> [!WARNING]
> 第一个界面会要求你选择内核版本，必须选择右边的 `MIT/GPL` 开源内核，否则重启后会黑屏

安装完成后重启，进入桌面后用以下命令确认：

```bash
nvidia-smi
```

应有类似表格的输出，例如：

```
┌──(username㉿KALI)-[~]
└─$ nvidia-smi
Sat Nov 6 7:6:7 1967       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.178.04             Driver Version: 580.178.04     CUDA Version: 13.0     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 6767        Off |   00000000:01:00.0  On |                  N/A |
| 67%   67C    P3             67W /  320W |    1442MiB /  10240MiB |     67%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A    314027      G   /usr/lib/xorg/Xorg                            944MiB |
|    0   N/A  N/A    314560      G   xfwm4                                           5MiB |
|    0   N/A  N/A    315681      G   /usr/lib/firefox-esr/firefox-esr              228MiB |
|    0   N/A  N/A    507792      G   ...cess-track-uuid=3190708988185955192        246MiB |
+-----------------------------------------------------------------------------------------+
```

安装 NVIDIA 官方 CUDA 仓库密钥：

```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
```

单次绕过 SHA1 签名验证问题，更新软件源：
> nvidia 仓库使用 SHA1 签名，Kali Linux 默认禁用 SHA1，需要绕过验证。

```bash
sudo apt update --allow-insecure-repositories
```

安装 CUDA Toolkit：

```bash
sudo apt install cuda-toolkit
```
> [!NOTE]
> 直接安装的 CUDA 版本应该是 12.4 ，若发现无法调用 CUDA ，可以使用 `sudo apt remove cuda-toolkit` 移除默认版本，再运行 `sudo apt install cuda-toolkit-12-4` 安装 12.4 版本。

这会安装 nvcc 编译器、CUDA 运行库及开发组件。如果提示依赖问题，先运行：

```bash
sudo apt --fix-broken install
```

**重启系统**，验证 CUDA 编译器：

```bash
/usr/local/cuda/bin/nvcc --version
```



### 2. 安装容器工具

Kali 基于 Debian，使用 `apt` 安装 Podman（推荐）或 Docker：

```bash
sudo apt update
sudo apt install -y podman fuse-overlayfs crun
```

> 也可用 `sudo apt install -y docker.io` 替代 Podman。推荐 Podman，因为它可以无 root 运行。

### 3. 克隆本仓库并放置 Resolve 安装包

1. 将本仓库克隆到用户主文件夹 `~/resolve-kali_linux` ：

   ```bash
   git clone --depth=1 https://github.com/eric6227/resolve-kali_linux.git
   ```
   > 新版本已经把 `kaliLinux` 分支合并到 `main` 分支，无需切换分支。

2. 从 [Blackmagic Design](https://www.blackmagicdesign.com) 官网下载 DaVinci Resolve 的 `.zip` 安装包。
3. 将 `.zip` 放到 `~/resolve-kali_linux/`，命名默认为如下格式。若不一样，需要重命名（免费版可省略 `_Studio`）：

   ```
   DaVinci_Resolve_Studio_<版本号>_Linux.zip
   ```

### 4. 添加 udev 规则（可选，用于加密狗 / Speed Editor 等硬件）

```bash
cd resolve-kali_linux
sudo cp 70-blackmagic-design.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 5. 构建镜像

```bash
cd resolve-kali_linux
RESOLVE_BASE_CONTAINER_IMAGE=docker.io/rockylinux:8.6 ./build.sh
# 注：Kali Linux 必须要使用 RESOLVE_NO_PIPEWIRE=1 禁用 PipeWire 音频。构建脚本已默认设为 1 ，只要不指定为非 1 即可。
```

> 构建过程会自动下载 CentOS Stream / Rocky Linux、安装依赖、安装 NVIDIA 驱动、并解包 Resolve。
> 默认使用中科大 Rocky Linux / EPEL 镜像站；如需切换镜像，可设置 `RESOLVE_PACKAGE_MIRROR` 为提供 Rocky Linux 与 EPEL 镜像的站点根 URL（例如 `https://mirrors.ustc.edu.cn`）。
>
> 如需在构建时把宿主机某个目录（例如 SMB 共享的项目素材）读写挂载到容器内，可通过 `MEDIA_MNT_PATH` 指定，脚本会把该目录映射写入 `resolve.rc`，容器内挂载点为 `/home/user-media`（读写）：
>
> ```
> MEDIA_MNT_PATH=/your/media/path RESOLVE_BASE_CONTAINER_IMAGE=docker.io/rockylinux:8.6 ./build.sh
> ```
>
> `resolve.rc` 会在启动时被 `resolve.sh` 自动加载（也可通过快捷方式或 `RESOLVE_RC_PATH=./resolve.rc ./resolve.sh` 显式指定）。注意：读写挂载下，删除容器内该目录的文件会同时删除宿主机源文件。

### 6. 启动 DaVinci Resolve

```bash
./resolve.sh
```

### 7. 验证 GPU

Resolve 启动后，在 `Preferences` → `System` → `Memory and GPU` 中选择 `CUDA`，并手动勾选 NVIDIA 显卡。宿主机运行 `nvidia-smi` 只能确认宿主机驱动正常，不能代替 Resolve 内的 GPU 选择。

请以桌面登录的普通用户运行，**不要使用 `sudo`**。首次启动会稍慢。

## 创建快捷方式

```
cd ~/resolve-kali_linux
chmod +x ./install-desktop.sh
./install-desktop.sh
```

然后在应用菜单中搜索“DaVinci Resolve”即可找到。可添加到收藏。

## 常用配置（环境变量）

完整说明见 [原版 README](./README_ORIGIN.md)，这里列出常用项：

| 环境变量 | 说明 |
| --- | --- |
| `RESOLVE_ZIP` | Resolve 安装包路径（默认取仓库内最新的 zip） |
| `RESOLVE_TAG` | 镜像 tag |
| `RESOLVE_NETWORK` | 容器网络模式（默认 `bridge`，允许访问互联网；设为 `none` 可断网，设为 `host` 可共享宿主机网络） |
| `RESOLVE_NVIDIA_VERSION` | 指定容器内 NVIDIA 驱动版本（默认跟随宿主机） |
| `RESOLVE_NO_PIPEWIRE` | 是否禁用 PipeWire 音频（**Kali Linux 必须禁用**） |
| `RESOLVE_BASE_CONTAINER_IMAGE` | 覆盖构建用的基础镜像 |
| `RESOLVE_PACKAGE_MIRROR` | 构建时使用的 Rocky Linux / EPEL 镜像站根 URL（默认 `https://mirrors.ustc.edu.cn`） |
| `RESOLVE_BUILD_X264_ENCODER_PLUGIN` | 构建 x264 编码器插件 |
| `RESOLVE_MOUNTS_PATH` | 覆盖 bind mount 根路径 |
| `RESOLVE_CONTAINER_ENGINE` | 指定容器引擎（podman / docker） |
| `RESOLVE_RC_PATH` | 指定一个 `resolve.rc` 脚本，用于加载额外配置 / 执行预启动命令 |
| `RESOLVE_ENABLE_HOST_SYSTEM_FONTS` | 将宿主机系统字体挂载进容器（默认启用；设为 `0` 可禁用） |
| `RESOLVE_BIND_SOURCES` / `RESOLVE_BIND_TARGETS` | 额外的自定义目录映射（数组，需一一对应） |
| `MEDIA_MNT_PATH` | 构建时（`build.sh`）额外读写挂载到容器内的目录（挂载点为 `/home/user-media`，写入 `resolve.rc`） |

## 数据目录（bind mount）

启动时会在仓库的 `mounts/` 下创建并映射以下目录到容器：

| 容器内路径 | 宿主机路径（相对 `mounts/`） |
| --- | --- |
| `/home/resolve` | `resolve-home` |
| `/opt/resolve/logs` | `logs` |
| `/opt/resolve/configs` | `configs` |
| `/opt/resolve/easyDCP` | `easyDCP` |
| `/opt/resolve/.license` | `license` |
| `/opt/resolve/Resolve Disk Database` | `database` |
| `/var/BlackmagicDesign` | `BlackmagicDesign` |
| `/opt/resolve/Media` | `Media` |
| `/opt/resolve/Fairlight` | `Fairlight` |
| `/opt/resolve/Extras` | `Extras` |
| `/opt/resolve/Immersive` | `Immersive` |

Resolve 容器退出后会删除容器本身，但表中的 bind mount 数据会保留。项目和导出文件请保存到容器内 `/home/resolve`（宿主机 `mounts/resolve-home`）或 `/opt/resolve/Media`（宿主机 `mounts/Media`）；项目数据库保存在 `/opt/resolve/Resolve Disk Database`（宿主机 `mounts/database`）。写到未列出的容器路径（例如 `/tmp` 或未挂载的 `/opt/resolve` 子目录）不会持久化。

## 容器身份与权限

容器启动时会使用固定主机名 `resolve-container`，并从 `mounts/container-machine-id` 派生固定 MAC（bridge 等独立网络下）。`/etc/machine-id`、`/opt/resolve/.license`、`/home/resolve` 和 `/var/BlackmagicDesign` 映射到宿主机持久化目录，因此这些容器内身份/状态在保留 mounts 数据且配置不变时可跨启动保留。

不要删除或替换 `mounts/container-machine-id`、`mounts/license`、`mounts/resolve-home` 或 `mounts/BlackmagicDesign`。移动仓库时也要保留这些数据，或通过 `RESOLVE_MOUNTS_PATH` 指回原来的 mounts 目录。此配置只固定上述容器身份和持久化状态，不会、也不能保证所有可识别特征（例如 GPU、宿主机硬件、网络模式或软件版本）不变。Blackmagic 的授权校验可能依据其他信息或服务端策略要求重新激活；请按软件许可条款使用，不能依赖容器配置绕过授权校验。若旧激活基于之前随机生成的 MAC，首次使用固定 MAC 后可能需要重新激活。

镜像默认以非 root 的 `resolve` 用户运行，不安装或授予 sudo 权限；启动时也会移除全部 Linux capabilities 并启用 `no-new-privileges`。容器镜像基础系统仍保留已锁定的 root 账户供系统构建需要，但 Resolve 进程不会以 root 身份启动。Podman 继续使用 rootless `keep-id` 模式。

## 故障排查

### `Failed to create application support directories`

Resolve 21.2 启动时会尝试在 `/opt/resolve/Immersive` 创建应用支持目录。该路径位于容器安装目录中，普通 `resolve` 用户不能直接写入。启动脚本现将其映射到仓库下由当前用户创建的 `mounts/Immersive`；**只需更新脚本并以普通用户从仓库目录启动，不需要重建镜像，也不要递归修改整个 `mounts/` 的所有权**：

```bash
cd ~/GithubRepo/resolve-kali_linux
./resolve.sh
```

如果仍报相同错误，检查该目录是否可写、所有者是否为当前用户：

```bash
id
stat -c '%u:%g %a %n' mounts/Immersive
```

只有在所有者或权限不正确时，才修复这个目录（不要对整个 `mounts/` 执行递归 `chown`）：

```bash
sudo chown -R "$(id -u):$(id -g)" mounts/Immersive
chmod -R u+rwX mounts/Immersive
```

### Resolve 没有声音

本容器通过宿主机的 PulseAudio 协议 socket 输出/输入声音；Kali 上的 PipeWire 通常由 `pipewire-pulse` 提供该兼容 socket。无需把 `/dev/snd` 直接透传给容器，也不应让 Resolve 绕过宿主机音频服务器独占声卡。

启动脚本会把宿主机 socket 挂载到容器专用的运行时目录，不再把宿主机的 `XDG_RUNTIME_DIR` 值直接当作容器路径；音频 socket 和 PulseAudio cookie 仅在存在时挂载。检查宿主机音频服务器和 socket（PipeWire 使用 `wpctl status`；纯 PulseAudio 可用 `pactl info`，该命令由 `pulseaudio-utils` 提供）：

```bash
wpctl status
test -S "$XDG_RUNTIME_DIR/pulse/native" && echo "PulseAudio socket is available"
```

若音频服务器命令失败，先修复宿主机的 PulseAudio / `pipewire-pulse` 会话；若 socket 不在 `$XDG_RUNTIME_DIR/pulse/native`，请检查 `XDG_RUNTIME_DIR` 是否指向当前桌面登录用户的运行时目录。启动 Resolve 时若提示找不到 PulseAudio-compatible socket，容器仍可启动，但音频不会经 PulseAudio 路由。

若日志中有 `PulseAudio: Unable to create stream: No such entity`，请在 Resolve 的 `Preferences` → `System` → `Video and Audio I/O` 中检查 `Audio I/O Engine`：选择 `ALSA` / `System Audio`（名称随版本而异），并使用默认/PulseAudio 输出设备；不要选择 `DeckLink`，除非确实使用并向容器提供了 DeckLink 音频硬件。启动脚本检测到保存的音频引擎为 DeckLink 时会提示，但不会自动覆盖用户设置。

若日志出现 `IO.Audio: Failed to decode ... Failed to decode the audio samples`，问题可能在素材解码而非声卡透传。当前 Resolve 镜像自带的 `libavcodec` 明确以 `--disable-decoder='aac*'`、`--disable-parser='aac*'` 构建；因此常见 MP4 AAC 音轨无法由该 Resolve 构建解码。单独在宿主机或容器中安装 FFmpeg 不会替换 Resolve 使用的私有解码库。

可在宿主机用 FFmpeg 将 AAC 音轨转换成 WAV PCM，再将 WAV 导入 Resolve：

```bash
ffmpeg -i input.mp4 -map 0:a:0 -vn -c:a pcm_s24le -ar 48000 output.wav
```

若对无法解码的素材执行“显示音乐节拍”会导致 Resolve 崩溃，先不要对原素材继续执行该操作；转换并导入 WAV 后再试。若 WAV 也触发崩溃，需要单独检查崩溃日志，不能仅凭音频解码错误断定崩溃原因。

其他问题（窗口无法移动/缩放、窗口过小、拖拽不生效、网络、注册码、字体等）与原版一致，请参考 [原版 README 的 Troubleshooting 章节](./README_ORIGIN.md)。

## 许可

本项目代码采用 [MIT License](./LICENSE)。DaVinci Resolve 及其 Studio 版、NVIDIA 驱动分别受各自许可协议约束，使用前请阅读并同意相应条款。

## 致谢

本项目为 [fat-tire/resolve](https://github.com/fat-tire/resolve) 的 Kali Linux 修改版，感谢原作者及贡献者的工作。原始仓库（含完整原理说明与故障排查）：

- <https://github.com/fat-tire/resolve>

## 声明
	
本项目修改的的代码使用 AI 生成，可能存在安全漏洞，请谨慎使用。