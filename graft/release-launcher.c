/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 John Knipper
 */
#include <mach-o/dyld.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(void)
{
    char executable[PATH_MAX], script[PATH_MAX];
    uint32_t size = sizeof executable;
    if (_NSGetExecutablePath(executable, &size)) return 1;
    char *separator = strrchr(executable, '/');
    if (!separator) return 1;
    *separator = '\0';
    if (snprintf(script, sizeof script, "%s/../Resources/launch-hosted.sh", executable) >= sizeof script)
        return 1;
    execl("/bin/sh", "sh", script, (char *)NULL);
    perror("PomAROS launcher");
    return 1;
}
