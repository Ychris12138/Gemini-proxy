#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    struct sockaddr_in addr = {0};
    addr.sin_len = sizeof addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)atoi(argv[2]));
    if (inet_pton(AF_INET, argv[1], &addr.sin_addr) != 1) return 2;
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0 || fcntl(fd, F_SETFL, O_NONBLOCK) < 0) return 2;
    int rc = connect(fd, (struct sockaddr *)&addr, sizeof addr);
    if (rc < 0 && errno == EINPROGRESS) {
        fd_set writes;
        FD_ZERO(&writes);
        FD_SET(fd, &writes);
        struct timeval timeout = {5, 0};
        if (select(fd + 1, NULL, &writes, NULL, &timeout) <= 0) return 1;
        int err = 0;
        socklen_t len = sizeof err;
        if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len) < 0 || err) return 1;
    } else if (rc < 0) {
        return 1;
    }
    close(fd);
    return 0;
}
