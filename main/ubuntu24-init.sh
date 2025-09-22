#!/bin/bash



show_help() {
    sudo echo "$0 [options]"
    sudo echo "options:"
    sudo echo "                        # Set ubuntu system environment."
    sudo echo "  cn                    # Set apt / pip / docker source to the commonly used mirror source in China."
    sudo echo "  host                  # Also set AI development environment in docker host."
    sudo echo "  -h | --help | help    # Show this help info."
    sudo echo ""
    sudo echo "sample:"
    sudo echo "  $0                    # Set ubuntu system environment only."
    sudo echo "  $0 cn                 # Set ubuntu system environment + Set Chinese mirror source."
    sudo echo "  $0 cn host            # Set ubuntu system environment + Set Chinese mirror source + Also set ai dev env in docker host."
    sudo echo "  $0 -h                 # Show help info."
}



init() {
    # Get arguments
    local is_cn=$1
    local is_forhost=$2


    # Update apt source
    if [ "$is_cn" = true ]; then
        sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
        sudo sed -i 's|https*://.*archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources
        sudo sed -i 's|https*://.*security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources
    fi

    sudo apt update
    sudo apt upgrade -y


    # Detect wsl
    local is_wsl=false
    if [[ $(systemd-detect-virt) == "wsl" ]]; then
        is_wsl=true
        sudo echo "WSL has been detected, enable wsl mode."
    fi


    # Install basic software
    sudo apt install -y vim openssh-server curl wget net-tools apt-transport-https ca-certificates software-properties-common lsb-release
    
    if [ "$is_wsl" = true ]; then
        code
    fi


    # Set default login user as root (for wsl)
    if [ "$is_wsl" = true ]; then
        sudo sed -i -r '/\[user\]/,/^\[/ s/^default=.+$/default=root/' /etc/wsl.conf
    fi


    # Open SSH
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sudo sed -i 's|#PermitRootLogin.*|PermitRootLogin yes|' /etc/ssh/sshd_config
    sudo systemctl enable ssh
    sudo systemctl start ssh


    # Install GPU Driver
    if [ "$is_wsl" = false ]; then
        sudo echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
        sudo update-initramfs -u
        sudo apt install -y nvidia-driver-575-server
    fi


    # Install CUDA toolkit and developer tools (for host system)
    if [ "$is_forhost" = true ]; then
        if [ "$is_wsl" = true ]; then
            if [[ $(dpkg --print-architecture) == "amd64" ]]; then
                sudo wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
                sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
                sudo wget https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda-repo-wsl-ubuntu-12-9-local_12.9.1-1_amd64.deb
                sudo dpkg -i cuda-repo-wsl-ubuntu-12-9-local_12.9.1-1_amd64.deb
                sudo cp /var/cuda-repo-wsl-ubuntu-12-9-local/cuda-*-keyring.gpg /usr/share/keyrings/
            else
                echo "ERROR: In wsl, cuda toolkit only support amd64 cpu architecture."
                exit 1
            fi
        else
            if [[ $(dpkg --print-architecture) == "amd64" ]]; then
                sudo wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
                sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600
                sudo wget https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda-repo-ubuntu2404-12-9-local_12.9.1-575.57.08-1_amd64.deb
                sudo dpkg -i cuda-repo-ubuntu2404-12-9-local_12.9.1-575.57.08-1_amd64.deb
                sudo cp /var/cuda-repo-ubuntu2404-12-9-local/cuda-*-keyring.gpg /usr/share/keyrings/
            elif [[ $(dpkg --print-architecture) == "arm64" ]]; then
                sudo wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/cuda-ubuntu2404.pin
                sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600
                sudo wget https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda-repo-ubuntu2404-12-9-local_12.9.1-575.57.08-1_arm64.deb
                sudo dpkg -i cuda-repo-ubuntu2404-12-9-local_12.9.1-575.57.08-1_arm64.deb
                sudo cp /var/cuda-repo-ubuntu2404-12-9-local/cuda-*-keyring.gpg /usr/share/keyrings/
            fi
        fi

        sudo apt-get update
        sudo apt-get -y install cuda-toolkit-12-9
        
        sudo touch /etc/profile.d/init_cuda_path.sh
        sudo chmod 777 /etc/profile.d/init_cuda_path.sh
        sudo echo -e 'export PATH="$PATH:/usr/lib/wsl/lib:/usr/local/cuda-13.0/bin"\nexport LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/cuda-13.0/lib64"\nexport CUDA_HOME=/usr/local/cuda-13.0' | sudo tee -a /etc/profile.d/init_cuda_path.sh > /dev/null
        sudo source /etc/profile.d/init_cuda_path.sh
    fi


    # Install docker
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    local docker_install_url="https://download.docker.com/linux/ubuntu"
    if [ "$is_cn" = true ]; then
        docker_install_url="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu"
    fi
    sudo echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $docker_install_url $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if [ "$is_cn" = true ]; then
        sudo mkdir -p /etc/docker
        local docker_mirror_content=$'{\n    "registry-mirrors": ["https://docker-0.unsee.tech","https://docker.1ms.run"]\n}'
        sudo echo "$docker_mirror_content" | sudo tee "/etc/docker/daemon.json" > /dev/null
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl start docker


    # Install NVIDIA Container Toolkit
    sudo curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && sudo curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sudo sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt-get update
    local NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
    sudo apt-get install -y \
        nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
        nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
        libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
        libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker


    # Install Pytorch (for host system)
    if [ "$is_forhost" = true ]; then
        sudo apt install -y python3 python3-pip python3-venv

        # Set pip source
        if [ "$is_cn" = true ]; then
            sudo pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple/
        fi

        sudo mkdir /home/pyenv.d/torch
        sudo python3 -m venv /home/pyenv.d/torch/.venv
        sudo source /home/pyenv.d/torch/.venv/bin/activate

        sudo pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu129

        sudo deactivate

        sudo echo "Set pytorch venv at '/home/pyenv.d/torch'."
    fi


    # After reboot you can work with cuda in docker
    # Pull the docker image for test: docker pull pytorch/pytorch:2.8.0-cuda12.8-cudnn9-devel
    #    Then you can run create container and run:
    #    docker run -it --gpus all --name docker_pytorch12.8_dev -v /home/docker_pytorch12.8_dev.d:/home pytorch/pytorch:2.8.0-cuda12.8-cudnn9-devel
    #    >> nvidia-smi
    #    >> nvcc --version
}



main() {
    # Handle args
    local is_cn=false
    local is_forhost=false
    
    for arg in "$@"; do
        case "${arg}" in
            "-h"|"--help"|"help")
                show_help
                exit 0
                ;;
            "cn")
                is_cn=true
                ;;
            "host")
                is_forhost=true
                ;;
            *)
                sudo echo "Warning: ignore invaild arg '${arg}'"
                ;;
        esac
    done


    # Init
    init "$is_cn" "$is_forhost"


    # Reboot
    sudo echo -e "Run $0 Completed, The system will restart in 5 seconds.\nPress any key to cancel restart."
    if read -t 5 -n 1; then
        sudo echo "Restart cancelled by user, remember to restart this system yourself later."
        exit 0
    fi

    sudo echo "System is restarting now..."
    sudo reboot
}



main "$@"