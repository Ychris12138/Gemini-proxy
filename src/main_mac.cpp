#if defined(__APPLE__)
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <string>
#include "core/Config.hpp"
#include "core/Logger.hpp"
#include "hooks/Hooks.hpp"
#include "hooks/ProcessName.hpp"

// This local experiment installs one network hook in the selected process only.
// It does not inject children, change sandbox policy, notify, or update itself.
static bool g_proxy_config_ready = false;
extern "C" bool gemini_proxy_config_ready() { return g_proxy_config_ready; }

__attribute__((constructor))
static void OnDylibLoad() {
    Core::Logger::SetLevel(Core::LogLevel::Error);
    char path[2048] = {};
    uint32_t size = sizeof path;
    if (_NSGetExecutablePath(path, &size) != 0) {
        Hooks::Install(false);
        return;
    }
    const std::string name = Hooks::ExtractBaseNameFromPathLike(path);
    const bool exactTarget = name == "Gemini";
    if (!exactTarget) {
        Hooks::Install(false);
        return;
    }
    Dl_info info = {};
    if (dladdr(reinterpret_cast<const void*>(&OnDylibLoad), &info) && info.dli_fname) {
        std::string libPath(info.dli_fname);
        const auto slash = libPath.find_last_of('/');
        if (slash != std::string::npos) {
            g_proxy_config_ready = Core::Config::Instance().Load(libPath.substr(0, slash) + "/config.json");
        }
    }
    Hooks::Install(true);
}

__attribute__((destructor))
static void OnDylibUnload() {
    Hooks::Uninstall();
}
#endif
