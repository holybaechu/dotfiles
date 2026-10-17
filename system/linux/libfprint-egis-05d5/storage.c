/* Inspect or clear the Egis 1c7a:05d5 reader through the installed libfprint.
 * Uses the same storage API as libfprint's examples/clear-storage.c.
 */
#include <fprint.h>
#include <gusb.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc == 2 && strcmp(argv[1], "--help") == 0) {
        printf("Usage: %s [--list|--clear]\n", argv[0]);
        return 0;
    }
    gboolean clear = argc == 2 && strcmp(argv[1], "--clear") == 0;
    if (argc > 2 || (argc == 2 && !clear && strcmp(argv[1], "--list") != 0)) {
        fprintf(stderr, "Usage: %s [--list|--clear]\n", argv[0]);
        return 1;
    }

    g_autoptr(FpContext) context = fp_context_new();
    g_autoptr(GError) error = NULL;
    g_autoptr(GPtrArray) prints = NULL;
    FpDevice *device = NULL;
    int result = 1;

    fp_context_enumerate(context);
    GPtrArray *devices = fp_context_get_devices(context);
    for (guint i = 0; i < devices->len; i++) {
        FpDevice *candidate = g_ptr_array_index(devices, i);
        g_autoptr(GUsbDevice) usb = NULL;
        if (strcmp(fp_device_get_driver(candidate), "egismoc") != 0)
            continue;
        g_object_get(candidate, "fpi-usb-device", &usb, NULL);
        if (!usb || g_usb_device_get_vid(usb) != 0x1c7a ||
            g_usb_device_get_pid(usb) != 0x05d5)
            continue;
        if (device) {
            fprintf(stderr, "Multiple matching readers found; refusing to choose.\n");
            return 1;
        }
        device = candidate;
    }
    if (!device) {
        fprintf(stderr, "Egis 1c7a:05d5 reader not found with the installed driver.\n");
        return 1;
    }
    if (!fp_device_open_sync(device, NULL, &error)) {
        fprintf(stderr, "Cannot open reader: %s\nStop fprintd and run with sudo.\n", error->message);
        return 1;
    }
    prints = fp_device_list_prints_sync(device, NULL, &error);
    if (!prints) {
        fprintf(stderr, "Cannot list reader storage: %s\n", error->message);
        goto close;
    }
    printf("Fingerprints stored on the reader: %u\n", prints->len);
    if (!clear || prints->len == 0) {
        if (clear && prints->len == 0)
            puts("Storage is already empty; no reset performed. Investigate the driver instead.");
        result = 0;
        goto close;
    }
    puts("This erases ALL fingerprints from this reader, including other users' or Windows enrollments.");
    printf("Type CLEAR ALL to continue: ");
    fflush(stdout);
    char confirmation[32];
    if (!fgets(confirmation, sizeof confirmation, stdin) ||
        strcmp(confirmation, "CLEAR ALL\n") != 0) {
        puts("Cancelled; no fingerprints deleted.");
        goto close;
    }
    if (!fp_device_clear_storage_sync(device, NULL, &error)) {
        fprintf(stderr, "Cannot clear reader storage: %s\n", error->message);
        goto close;
    }
    g_clear_pointer(&prints, g_ptr_array_unref);
    prints = fp_device_list_prints_sync(device, NULL, &error);
    if (!prints || prints->len != 0) {
        fprintf(stderr, "Could not confirm empty storage: %s\n",
                error ? error->message : "fingerprints remain on the reader");
        goto close;
    }
    puts("Reader storage cleared and verified empty.");
    result = 0;

close:
    g_clear_error(&error);
    if (!fp_device_close_sync(device, NULL, &error)) {
        fprintf(stderr, "Cannot close reader: %s\n", error->message);
        result = 1;
    }
    return result;
}
