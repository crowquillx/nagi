{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  aiEnabled = get [ "features" "ai" "enable" ] false;
  comfyuiEnabled = get [ "features" "ai" "comfyui" "enable" ] false;
  ollamaEnabled = get [ "features" "ai" "ollama" "enable" ] false;
  openWebuiEnabled = get [ "features" "ai" "openWebui" "enable" ] false;
  # latest-cuda
  comfyuiImage = "ghcr.io/utensils/comfyui-nix@sha256:d16e82bfa6036fe49faaaf9d36bf52dff03efdbb43676fb99d1a452181ccef0c";
  # latest
  ollamaImage = "docker.io/ollama/ollama@sha256:6345fbc18bd73a1e16404be681dbc6fd291a027cab43ed541abe78c4c81051b0";
  # main
  openWebuiImage = "ghcr.io/open-webui/open-webui@sha256:a26effeb220e132482bf7e0560b3404843e7bc40d23051144e062960df8df6b0";
in
{
  config = lib.mkMerge [
    (lib.mkIf aiEnabled {
      virtualisation.oci-containers.backend = "podman";
      hardware.nvidia-container-toolkit.enable = true;

      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "ai-comfyui";
          text = ''
            if ! sudo podman image exists ${comfyuiImage}; then
              echo "ComfyUI image is not present locally; pulling it now."
              sudo podman pull --policy missing --retry 20 --retry-delay 30s ${comfyuiImage}
            fi

            systemctl start --no-block podman-comfyui.service
            echo "Starting ComfyUI at http://127.0.0.1:8188"
            echo "Following logs; press Ctrl-C to stop watching without stopping ComfyUI."
            exec journalctl -fu podman-comfyui.service
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-ollama";
          text = ''
            if ! sudo podman image exists ${ollamaImage}; then
              echo "Ollama image is not present locally; pulling it now."
              sudo podman pull --policy missing --retry 20 --retry-delay 30s ${ollamaImage}
            fi

            systemctl start --no-block podman-ollama.service
            echo "Starting Ollama at http://127.0.0.1:11434"
            echo "Following logs; press Ctrl-C to stop watching without stopping Ollama."
            exec journalctl -fu podman-ollama.service
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-webui";
          text = ''
            if ! sudo podman image exists ${openWebuiImage}; then
              echo "Open WebUI image is not present locally; pulling it now."
              sudo podman pull --policy missing --retry 20 --retry-delay 30s ${openWebuiImage}
            fi

            systemctl start --no-block podman-open-webui.service
            echo "Starting Open WebUI at http://127.0.0.1:8080"
            echo "Following logs; press Ctrl-C to stop watching without stopping Open WebUI."
            exec journalctl -fu podman-open-webui.service
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-pull-comfyui";
          text = ''
            sudo podman pull --policy newer --retry 20 --retry-delay 30s ${comfyuiImage}
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-pull-ollama";
          text = ''
            sudo podman pull --policy newer --retry 20 --retry-delay 30s ${ollamaImage}
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-pull-webui";
          text = ''
            sudo podman pull --policy newer --retry 20 --retry-delay 30s ${openWebuiImage}
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-pull";
          text = ''
            ai-pull-comfyui
            ai-pull-ollama
            ai-pull-webui
          '';
        })
        (pkgs.writeShellApplication {
          name = "ai-stop";
          text = ''
            systemctl stop podman-open-webui.service || true
            systemctl stop podman-comfyui.service || true
            systemctl stop podman-ollama.service || true
          '';
        })
      ];
    })

    (lib.mkIf (aiEnabled && comfyuiEnabled) {
      systemd.tmpfiles.rules = [
        "d /var/lib/comfyui 0755 root root -"
      ];

      virtualisation.oci-containers.containers.comfyui = {
        autoStart = false;
        image = comfyuiImage;
        pull = "never";
        ports = [ "127.0.0.1:8188:8188" ];
        volumes = [ "/var/lib/comfyui:/data" ];
        devices = [ "nvidia.com/gpu=all" ];
        cmd = [
          "--listen"
          "0.0.0.0"
          "--port"
          "8188"
          "--base-directory"
          "/data"
          "--enable-manager"
        ];
      };
    })

    (lib.mkIf (aiEnabled && ollamaEnabled) {
      systemd.tmpfiles.rules = [
        "d /var/lib/ollama 0755 root root -"
      ];

      virtualisation.oci-containers.containers.ollama = {
        autoStart = false;
        image = ollamaImage;
        pull = "never";
        ports = [ "127.0.0.1:11434:11434" ];
        volumes = [ "/var/lib/ollama:/root/.ollama" ];
        devices = [ "nvidia.com/gpu=all" ];
        environment = {
          OLLAMA_HOST = "0.0.0.0:11434";
        };
      };
    })

    (lib.mkIf (aiEnabled && openWebuiEnabled) {
      systemd.tmpfiles.rules = [
        "d /var/lib/open-webui 0755 root root -"
      ];

      virtualisation.oci-containers.containers.open-webui = {
        autoStart = false;
        image = openWebuiImage;
        pull = "never";
        ports = [ "127.0.0.1:8080:8080" ];
        volumes = [ "/var/lib/open-webui:/app/backend/data" ];
        dependsOn = lib.optionals ollamaEnabled [ "ollama" ];
        environment = {
          OLLAMA_BASE_URL = "http://host.containers.internal:11434";
          OLLAMA_API_BASE_URL = "http://host.containers.internal:11434";
          SCARF_NO_ANALYTICS = "True";
          DO_NOT_TRACK = "True";
          ANONYMIZED_TELEMETRY = "False";
        };
      };
    })
  ];
}
