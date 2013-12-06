/*
 *  Copyright (C) 2008-2013, Cable Television Laboratories, Inc.
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

#ifndef __H_DTCPIP
#define __H_DTCPIP

unsigned int dtcpip_get_encrypted_sz (unsigned int cleartext_size, unsigned int base_pcp_payload);
int dtcpip_cmn_init(char* pIPAndPort);

int dtcpip_snk_init(void);
int dtcpip_snk_open(char* ip_addr, unsigned short ip_port, int *session_handle);
int dtcpip_snk_alloc_decrypt(int session_handle, char* encrypted_data, size_t encrypted_size,
 char** cleartext_data, size_t* cleartext_size);
int dtcpip_snk_free(char* cleartext_data);
int dtcpip_snk_close(int session_handle);

int dtcpip_src_init(unsigned short dtcp_port);
int dtcpip_src_open(int* session_handle, int is_audio_only);
int dtcpip_src_alloc_encrypt(int session_handle, unsigned char cci,
char* cleartext_data, size_t cleartext_size,
char** encrypted_data,size_t* encrypted_size);
int dtcpip_src_free(char* encrypted_data);
int dtcpip_src_close(int session_handle);
int dtcpip_src_close_socket(int session_handle);

int CVP2_DTCPIP_Init(char *pCertStorageDir);
int CVP2_DTCPIP_GetLocalCert (unsigned char *pLocalCert, unsigned int *pLocalCertSize);
int CVP2_DTCPIP_VerifyRemoteCert(unsigned char *pRemoteCert,  unsigned int nRemoteCertSz);
int CVP2_DTCPIP_SignData( unsigned char *pData, unsigned int nDataSz,
unsigned char *pSignature, unsigned int *pnSignatureSz);
int CVP2_DTCPIP_VerifyData(unsigned char *pData, unsigned int nDataSz,
unsigned char *pSignature, unsigned char *pRemoteCert );

#endif
