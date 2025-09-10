# AI Dev Env Igniter - 一键 AI 开发环境部署脚本

此脚本面向单机单 Nvidia 显卡的用户，这也是常见的开发设备配置。目标是一键式配置开发 AI 环境。

此环境把 Ubuntu 24 作为 Docker 宿主机，并允许在 Docker 容器中使用显卡驱动和 CUDA，以运行不同的 AI 开发环境。实现对于同一个开发机器，快速（秒级）切换不同 AI 的开发环境的功能。

支持装载 Ubuntu 24 的实体机器和 WSL。对于 ProxmoxVE / ESXI 虚拟机，请先把显卡直通 / 通过 vGPU 分配给目标 Ubuntu 24 虚拟机，再在虚拟机上执行此脚本。

# 使用方法

## 对于 Ubuntu 24 实体机用户
1. 提升为 root 用户
```shell
sudo passwd root
>> <passwd>
>> <root-passwd>
su root
>> <root-passwd>
```
2. 运行此脚本
```shell
apt update
apt install -y git
cd /home # 或者任何你喜欢的位置
git clone git@github.com:kiroeko/ai-dev-env-igniter.git
./ai-dev-env-igniter/main/ubuntu24-init.sh
# 或按需使用 cn 参数：./ai-dev-env-igniter/main/ubuntu24-init.sh cn
```
## 对于 WSL 用户
1. 首先确保 Windows 系统运行 Windows 10 版本 2004 及更高版本（内部版本 19041 及更高版本）或 Windows 11，且已安装了最新 [Nvidia 显卡驱动](https://www.nvidia.cn/drivers/lookup/)。
2. 下载[此代码仓库](https://github.com/kiroeko/ai-dev-env-igniter/archive/refs/heads/main.zip)。
3. 使用 Powershell 运行此代码仓库中的 `wsl/wsl-init.ps1`。
4. 在打开的 WSL 终端设置好用户信息，并运行此代码仓库中的`main/ubuntu24-init.sh`（如果当前并非 root 用户，会要求输入当前用户的密码）。
5. 关闭终端，并重新打开 Powershell，输入 WSL。
6. 现在可以使用了。

# 配置后，开发环境的使用用例

下面以部署最近较受欢迎的 AI playground - [minimind](https://github.com/jingyaogong/minimind) 开发环境为例：
```shell
docker pull pytorch/pytorch:2.3.0-cuda12.1-cudnn8-devel
docker run -it -p 80:80 -p 8080:8080 -p 8501:8501 -p 8998:8998 --gpus all --name minimind_dev -v /home/minimind_dev.d:/home pytorch/pytorch:2.3.0-cuda12.1-cudnn8-devel
# 进入 Docker 容器
>> cd /home
>> apt update
>> apt install -y git git-lfs
>> git lfs install
>> git clone git@github.com:jingyaogong/minimind.git
>> cd minimind
>> pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
>> pip install streamlit
>> git clone https://huggingface.co/jingyaogong/MiniMind2
>> cd dataset
>> git clone https://www.modelscope.cn/datasets/gongjy/minimind_dataset.git
>> cd ../scripts
>> nohup streamlit run web_demo.py &
# 注意：执行上述命令后，如需退出但不关闭容器，请按 Ctrl+P 然后 Ctrl+Q
```