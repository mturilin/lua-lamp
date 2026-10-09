#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <dns_sd.h>

static void bonjour_reply(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                          DNSServiceErrorType errorCode, const char *serviceName,
                          const char *regtype, const char *replyDomain, void *context) {
    (void)sdRef; (void)flags; (void)interfaceIndex; (void)errorCode;
    (void)serviceName; (void)regtype; (void)replyDomain; (void)context;
}

static void trigger_local_network_prompt(const char *target_ip) {
    if (!target_ip || strlen(target_ip) == 0) {
        target_ip = "192.168.1.1";
    }

    // 1. DNSServiceBrowse triggers the standard macOS Local Network permission prompt
    static DNSServiceRef sdRef = NULL;
    DNSServiceBrowse(&sdRef, 0, 0, "_http._tcp", NULL, bonjour_reply, NULL);

    // 2. NWBrowser (Network.framework) Bonjour discovery
    nw_browse_descriptor_t desc = nw_browse_descriptor_create_bonjour_service("_http._tcp", NULL);
    nw_parameters_t bparams = nw_parameters_create();
    nw_browser_t browser = nw_browser_create(desc, bparams);
    nw_browser_set_queue(browser, dispatch_get_main_queue());
    nw_browser_start(browser);

    // 3. UDP probe to the local gateway
    nw_endpoint_t endpoint = nw_endpoint_create_host(target_ip, "53");
    nw_parameters_t params = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_connection_t conn = nw_connection_create(endpoint, params);
    nw_connection_set_queue(conn, dispatch_get_main_queue());
    nw_connection_start(conn);

    dispatch_data_t data = dispatch_data_create("lualamp", 7, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    nw_connection_send(conn, data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, false, ^(nw_error_t _Nullable error) {});
}

// In-process constructor: triggers automatically when loaded into process
__attribute__((constructor))
static void netauth_dylib_init(void) {
    trigger_local_network_prompt("192.168.1.1");
}

int luaopen_libnetauth(void *L) {
    (void)L;
    return 0;
}

// Standalone CLI helper entry point
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        const char *target = argc > 1 ? argv[1] : "192.168.1.1";
        trigger_local_network_prompt(target);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
        dispatch_main();
    }
    return 0;
}
