/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Prasanna Modem <prasanna@ecaspia.com>
 *
 * This file is part of Rygel.
 * 
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CABLE TELEVISION LABORATORIES
 * INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Prasanna Modem <prasanna@ecaspia.com>
 */
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
