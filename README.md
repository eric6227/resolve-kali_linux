# 在 Kali Linux 上容器化运行 DaVinci Resolve [Studio]（x86_64 + NVIDIA）
> [!NOTICE]
> - 本项目基于 fat-tire/resolve 项目，针对 Kali Linux 宿主机修改。
> - 本项目仅在 Davinci Resolve Studio 版本上测试过，免费版本可能不兼容。
> - 请勿使用盗版 Davinci Resolve Studio 安装包。使用盗版导致的问题请勿提交 Issue。
> - 由于本人（eric6227）多次测试触发激活次数限制，当前版本尚未进行软件功能的测试。

这是一个基于 [fat-tire/resolve](https://github.com/fat-tire/resolve) 项目、针对 **Kali Linux** 宿主机修改的版本。

原项目面向 Ubuntu / Debian / Mint / PopOS / RockyOS 等发行版；本仓库在此基础上做了针对 Kali Linux 的调整，其余原理、目录映射、环境变量、故障排查等与原版基本一致。

> **原版说明文档**：
> - 原始仓库 README：[fat-tire/resolve - README.md](https://github.com/fat-tire/resolve)
> - 本仓库内保留的原版完整说明：[README_ORIGIN.md](./README_ORIGIN.md)

## 这是什么

[DaVinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve/) 是 Blackmagic Design 推出的免费（及付费 Studio 版）非线性剪辑软件。它最初是为（现已停止维护的）CentOS 发行版设计的，在其他发行版上直接安装往往会有库兼容性问题。

本项目的思路是：**宿主机用 Kali Linux，通过容器（Podman / Docker）在 CentOS Stream / Rocky Linux 的 guest 环境中运行 DaVinci Resolve**，这样它就能运行在它“期望”的原生环境里，同时你的工程、素材、字体、配置等数据都通过 bind mount 保存在宿主机上，容器本身保持“一次性”（ephemeral）。

## 与 Kali Linux 相关的注意事项

- Kali 是 Debian 系发行版，安装容器工具链使用 `apt`。
- Kali 默认使用 root 用户、默认 shell 为 Zsh；本脚本在普通用户下运行即可，无需 root。
- NVIDIA 驱动的安装方式与 Ubuntu 不同（Kali 没有“软件与更新 → 附加驱动”界面），需要通过 Kali 官方仓库或 NVIDIA 官方 `.run` 包安装，详见下文步骤。
- 图形会话建议使用 X11（Xorg）。Kali 默认桌面通常是 Xfce / GNOME，理论上 Wayland 也能工作，但 X11 兼容性最稳。
- 中文字形使用宿主机字体；若系统没有 CJK 字体，可安装 `fonts-noto-cjk`。

## 运行环境要求

- x86_64 主机，内存建议 16GB 以上（Blackmagic Design 官方对 Studio 版建议 32GB）。
- 一块较新的 NVIDIA GPU（显存建议 4GB 以上）。
- 已安装 Kali Linux（建议使用普通用户而非 root 运行）。
- （可选）DaVinci Resolve Studio 的 USB 加密狗（Dongle）。
- （可选）DaVinci Resolve Speed Editor（仅 USB；蓝牙支持见原版 README）。
- （可选）激活码（Registration Code）——**未经充分测试，风险自负**；默认 bridge 网络允许容器访问互联网。

## 安装步骤（Kali Linux）

### 1. 安装 NVIDIA 驱动

首先安装驱动：

```bash
# 使用 Kali 官方仓库
sudo apt update
sudo apt install -y nvidia-driver nvidia-smi
```

安装完成后重启，并用以下命令确认：

```bash
nvidia-smi
```

应有类似表格的输出，例如：

```
┌──(username㉿KALI)-[~]
└─$ nvidia-smi
Sat Nov 6 7:6:7 1967       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.163.01             Driver Version: 550.163.01     CUDA Version: 12.4     |
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
   git clone --depth=1 --branch kaliLinux https://github.com/eric6227/resolve-kali_linux.git
   ```

   > 如果之前已经克隆过仓库，可用以下命令切换到 `kaliLinux` 分支：
   >
   > ```bash
   > git fetch origin
   > git checkout kaliLinux
   > ```

2. 从 [Blackmagic Design](https://www.blackmagicdesign.com) 官网下载 DaVinci Resolve 的 `.zip` 安装包。
3. 将 `.zip` 放到 `~/resolve-kali_linux/`，并重命名为如下格式（免费版可省略 `_Studio`）：

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
| `RESOLVE_BUILD_X264_ENCODER_PLUGIN` | 构建 x264 编码器插件 |
| `RESOLVE_MOUNTS_PATH` | 覆盖 bind mount 根路径 |
| `RESOLVE_CONTAINER_ENGINE` | 指定容器引擎（podman / docker） |
| `RESOLVE_RC_PATH` | 指定一个 `resolve.rc` 脚本，用于加载额外配置 / 执行预启动命令 |
| `RESOLVE_ENABLE_HOST_SYSTEM_FONTS` | 将宿主机系统字体挂载进容器（默认启用；设为 `0` 可禁用） |
| `RESOLVE_BIND_SOURCES` / `RESOLVE_BIND_TARGETS` | 额外的自定义目录映射（数组，需一一对应） |

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

## 激活标识持久化

为避免每次启动都获得随机的网络 MAC，`resolve.sh` 会从 `mounts/container-machine-id` 计算一个本地管理的固定 MAC，并在 bridge 网络下通过 Podman/Docker 的 `--mac-address` 使用；容器主机名也固定为 `resolve-container`。`/etc/machine-id`、`/opt/resolve/.license`、`/home/resolve` 和 `/var/BlackmagicDesign` 同样映射到宿主机持久化目录。

不要删除或替换 `mounts/container-machine-id`、`mounts/license`、`mounts/resolve-home` 或 `mounts/BlackmagicDesign`。移动仓库时也要保留这些数据，或通过 `RESOLVE_MOUNTS_PATH` 指回原来的 mounts 目录。更改这些身份数据、切换到 `host`/`none` 网络、重建/升级 Resolve 或更换宿主机，都可能让 Blackmagic 的授权服务重新要求激活；这是硬件指纹校验的一部分，不能保证仅靠容器配置避免服务端重新验证。若旧激活基于之前随机生成的 MAC，首次使用固定 MAC 后可能需要再激活一次。

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

其他问题（窗口无法移动/缩放、窗口过小、拖拽不生效、网络、注册码、字体、声音等）与原版一致，请参考 [原版 README 的 Troubleshooting 章节](./README_ORIGIN.md)。

## 许可

本项目代码采用 [MIT License](./LICENSE)。DaVinci Resolve 及其 Studio 版、NVIDIA 驱动分别受各自许可协议约束，使用前请阅读并同意相应条款。

## 致谢

本项目为 [fat-tire/resolve](https://github.com/fat-tire/resolve) 的 Kali Linux 修改版，感谢原作者及贡献者的工作。原始仓库（含完整原理说明与故障排查）：

- <https://github.com/fat-tire/resolve>

## 声明
	
本项目修改的的代码使用 AI 生成，可能存在安全漏洞，请谨慎使用。