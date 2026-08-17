#include "logging.h"

#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <SDL_timer.h>
#include <SDL_mutex.h>

static bool log_header(int level, const char *tag);

static bool check_level(int level, const char *tag);

static SDL_mutex *lock = NULL;

void commons_logging_init(const char *context_name) {
    (void) context_name;
    lock = SDL_CreateMutex();
}

void commons_logging_deinit() {
    SDL_DestroyMutex(lock);
    lock = NULL;
}

void commons_log_vprintf(commons_log_level level, const char *tag, const char *fmt, va_list arg) {
    if (lock == NULL) {
        return;
    }
    char msg[1024];
    vsnprintf(msg, sizeof(msg), fmt, arg);
    size_t len = strlen(msg);
    if (len > 0 && msg[len - 1] == '\n') {
        msg[len - 1] = '\0';
    }
    commons_log_notify_listener(level, tag, msg);

    SDL_LockMutex(lock);
    if (!log_header(level, tag)) {
        SDL_UnlockMutex(lock);
        return;
    }
    fputs(msg, stderr);
    fprintf(stderr, "\x1b[0m\n");
    SDL_UnlockMutex(lock);
}

static bool log_header(int level, const char *tag) {
    float time = (float) SDL_GetTicks() / 1000.0f;
    int taglen = (int) strlen(tag);
    if (taglen > 16) {
        taglen = 16;
    }
    int msgpad = 17 - taglen;
    switch (level) {
        case COMMONS_LOG_LEVEL_INFO:
            fprintf(stderr, "[%08.3f] [%.*s]\x1b[36m%-*sI ", time, taglen, tag, msgpad, " ");
            break;
        case COMMONS_LOG_LEVEL_WARN:
            fprintf(stderr, "[%08.3f] [%.*s]\x1b[33m%-*sW ", time, taglen, tag, msgpad, " ");
            break;
        case COMMONS_LOG_LEVEL_ERROR:
            fprintf(stderr, "[%08.3f] [%.*s]\x1b[31m%-*sE ", time, taglen, tag, msgpad, " ");
            break;
        case COMMONS_LOG_LEVEL_FATAL:
            fprintf(stderr, "[%08.3f] [%.*s]\x1b[41m%-*sF ", time, taglen, tag, msgpad, " ");
            break;
        case COMMONS_LOG_LEVEL_VERBOSE:
            fprintf(stderr, "[%08.3f] [%.*s]\x1b[34m%-*sV ", time, taglen, tag, msgpad, " ");
            break;
        case COMMONS_LOG_LEVEL_DEBUG:
            fprintf(stderr, "[%08.3f] [%.*s]%-*sD ", time, taglen, tag, msgpad, " ");
            break;
        default:
            return false;
    }
    return true;
}
