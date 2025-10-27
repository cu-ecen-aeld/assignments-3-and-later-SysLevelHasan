#include "systemcalls.h"
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <stdarg.h>

/**
 * @param cmd command to execute with system()
 * @return true if the command succeeded (return code 0), false otherwise
 */
bool do_system(const char *cmd)
{
    if (cmd == NULL)
        return false;

    int ret = system(cmd);

    if (ret == -1)
        return false;

    return WIFEXITED(ret) && (WEXITSTATUS(ret) == 0);
}

/**
 * @param count argument count
 * @param ... list of arguments starting with file to execute
 * @return true if the program executed successfully, false otherwise
 */
bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);

    char *command[count + 1];
    for (int i = 0; i < count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    va_end(args);

    pid_t pid = fork();
    if (pid == -1)
        return false;

    if (pid == 0)
    {
        execv(command[0], command);
        _exit(1); // execvp failed
    }

    int status;
    if (waitpid(pid, &status, 0) == -1)
        return false;

    return WIFEXITED(status) && (WEXITSTATUS(status) == 0);
}

/**
 * @param outputfile file to redirect stdout and stderr to
 * @param count argument count
 * @param ... list of arguments starting with file to execute
 * @return true if the program executed successfully, false otherwise
 */
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);

    char *command[count + 1];
    for (int i = 0; i < count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    va_end(args);

    pid_t pid = fork();
    if (pid == -1)
        return false;

    if (pid == 0)
    {
        int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0)
            _exit(1);

        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        close(fd);

        execv(command[0], command);
        _exit(1);
    }

    int status;
    if (waitpid(pid, &status, 0) == -1)
        return false;

    return WIFEXITED(status) && (WEXITSTATUS(status) == 0);
}
