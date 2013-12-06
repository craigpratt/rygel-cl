/* 
 *  Copyright (C) 2008-2013, Cable Television Laboratories, Inc.
 *
 *  Author: Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 *
 *  This file is part of Rygel.
 * 
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 2. This program is distributed
 *  in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 *  even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE. See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program.  If not, see  <http://www.gnu.org/licenses/>.
 *
 *  Please contact CableLabs if you need additional information or
 *  have any questions.
 *
 *      CableLabs
 *      858 Coal Creek Cir
 *      Louisville, CO 80027-9750
 *      303 661-9100
 *      oc-mail@cablelabs.com
 *
 *  If you or the company you represent has a separate agreement with CableLabs
 *  concerning the use of this code, your rights and obligations with respect
 *  to this code shall be as set forth therein. No license is granted hereunder
 *  for any other purpose.
 */

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
