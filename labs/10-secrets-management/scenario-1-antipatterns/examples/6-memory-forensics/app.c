#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main() {
    // Allocate memory and store a secret
    char *secret = malloc(100);
    strcpy(secret, "DATABASE_PASSWORD=VerySecretPassword123");
    
    printf("App started. Secret is in memory.\n");
    printf("Process PID: %d\n", getpid());
    printf("Secret address: %p\n", (void*)secret);
    printf("\nSecret will remain in memory...\n");
    printf("On Linux VM, use: gdb -p %d\n", getpid());
    printf("Then: (gdb) generate-core-file /tmp/core.dump\n");
    printf("Then: strings /tmp/core.dump | grep PASSWORD\n");
    
    // Keep process alive
    while(1) {
        sleep(60);
    }
    
    return 0;
}
