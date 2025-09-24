#include <stdio.h>
#include <curl/curl.h> 

int main() {
    printf("libcurl version: %s\n", curl_version()); // ランタイムで使う関数
    return 0;
}
