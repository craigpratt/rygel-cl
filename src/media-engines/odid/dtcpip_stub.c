#include <stdio.h>
#include <string.h> // memcpy, strrchr, strlen

#include "dtcpip.h"

unsigned int dtcpip_get_encrypted_sz (unsigned int cleartext_size, unsigned int base_pcp_payload)
{
    return 0;
}

int dtcpip_cmn_init(char* pIPAndPort)
{
    return -1;
}

void dtcpip_cmn_get_version(char* string, size_t length)
{
    
}

int dtcpip_src_init(unsigned short dtcp_port)
{
    return -1;
}

int dtcpip_src_open(int* session_handle, int is_audio_only)
{
    return -1;
}

int dtcpip_src_alloc_encrypt(int session_handle,
                 unsigned char cci,
                 char* cleartext_data, size_t cleartext_size,
                 char** encrypted_data, size_t* encrypted_size)
{
    return -1;
}

int dtcpip_src_free(char* encrypted_data)
{
    return -1;
}

int dtcpip_src_close(int session_handle)
{
    return -1;
}

int dtcpip_snk_init(void)
{
    return -1;
}

int dtcpip_snk_open(
                 char* ip_addr, unsigned short ip_port,
                 int *session_handle)
{
    return -1;
}

int dtcpip_snk_alloc_decrypt(int session_handle,
                 char* encrypted_data, size_t encrypted_size,
                 char** cleartext_data, size_t* cleartext_size)
{
    return -1;
}

int dtcpip_snk_free(char* cleartext_data)
{
    return -1;
}

int dtcpip_snk_close(int session_handle)
{
    return -1;
}
