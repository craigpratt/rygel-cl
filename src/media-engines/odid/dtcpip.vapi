[CCode (cheader_filename = "dtcpip.h")]
namespace Dtcpip {
    //Common functions
    [CCode (cname = "dtcpip_get_encrypted_sz")]
    public static uint64 get_encrypted_length (uint64 cleartext_length, uint64 encrypted_length);
    [CCode (cname = "dtcpip_cmn_init")]
    public static int init_dtcp_library ([CCode (type = "char*")]string storage_path);
//    [CCode (cname = "dtcpip_cmn_get_version")]
//    public static void cmn_get_version(char* str, int length);

    // Source Functions
    [CCode (cname = "dtcpip_src_init")]
    public static int server_dtcp_init (ushort dtcp_port);
    [CCode (cname = "dtcpip_src_open")]
    public static int server_dtcp_open (out int session_handle, int is_audio_only);
    [CCode (cname = "dtcpip_src_alloc_encrypt")]
    public static int server_dtcp_encrypt (int session_handle, uchar cci, [CCode (array_length_pos = 3.1)] uint8[] cleartext_data,
                                           [CCode (array_length_pos = 5.1)] out unowned uint8[] encrypted_data);
    [CCode (cname = "dtcpip_src_free")]
    public static int server_dtcp_free ([CCode (array_length = false , type = "char*")] uint8[] encrypted_data);
    [CCode (cname = "dtcpip_src_close")]
    public static int server_dtcp_close (int session_handle);
    [CCode (cname = "dtcpip_src_close_socket")]
    public static int server_dtcp_close_socket (int session_handle);
    
    //Sink Functions
    [CCode (cname = "dtcpip_snk_init")]
    public static int client_dtcp_init ();
    [CCode (cname = "dtcpip_snk_open")]
    int client_dtcp_open (string ip_addr, ushort ip_port, out int session_handle);
    [CCode (cname = "dtcpip_snk_alloc_decrypt")]
    public static int client_dtcp_decrypt (int session_handle, [CCode (array_length_pos = 2.1)] uint8[] encrypted_data,
                                           [CCode (array_length_pos = 4.1)] out unowned uint8[] cleartext_data);
    [CCode (cname = "dtcpip_snk_free")]
    public static int client_dtcp_free ([CCode (array_length = false , type = "char*")] uint8[] cleartext_data);
    [CCode (cname = "dtcpip_snk_close")]
    public static int client_dtcp_close (int session_handle);

    // CVP2 functions
    [CCode (cname = "CVP2_DTCPIP_Init")]    
    public static int cvp2_dtcp_init(string pCertStorageDir);
    [CCode (cname = "CVP2_DTCPIP_GetLocalCert")]    
    public static int get_local_cert (uchar *pLocalCert, [CCode (type = "unsigned int")] uint64 *pLocalCertSize);
    [CCode (cname = "CVP2_DTCPIP_VerifyRemoteCert")]    
    public static int verify_remote_cert(uchar *pRemoteCert, [CCode (type = "unsigned int")] uint64 nRemoteCertSz);
    [CCode (cname = "CVP2_DTCPIP_SignData")]    
    public static int sign_data(uchar *pData,[CCode (type = "unsigned int")] uint64 nDataSz, uchar *pSignature, [CCode (type = "unsigned int")] out uint64 pnSignatureSz);
    [CCode (cname = "CVP2_DTCPIP_VerifyData")]    
    public static int verify_data(uchar *pData, [CCode (type = "unsigned int")] uint64 nDataSz, uchar *pSignature, uchar *pRemoteCert);
}
