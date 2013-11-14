#ifndef __H_DTCPIP
#define __H_DTCPIP

unsigned int dtcpip_get_encrypted_sz (unsigned int cleartext_size, unsigned int base_pcp_payload);
int dtcpip_cmn_init(char* pIPAndPort);

int dtcpip_snk_init(void);
int dtcpip_snk_open(char* ip_addr, unsigned short ip_port, int *session_handle);
int dtcpip_snk_alloc_decrypt(int session_handle, char* encrypted_data, unsigned int encrypted_size,
 char** cleartext_data, unsigned int* cleartext_size);
int dtcpip_snk_free(char* cleartext_data);
int dtcpip_snk_close(int session_handle);

int dtcpip_src_init(unsigned short dtcp_port);
int dtcpip_src_open(int* session_handle, int is_audio_only);
int dtcpip_src_alloc_encrypt(int session_handle, unsigned char cci,
char* cleartext_data, unsigned int cleartext_size,
char** encrypted_data,unsigned int* encrypted_size);
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
