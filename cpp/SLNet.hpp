#pragma once

#include "BitStream.hpp"
#if defined(_WIN32)
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#endif

#include "Socket.hpp"
#include "UNIXSock.h"


using callback_receive = std::function<void(unsigned int, BitStream, const char*, unsigned int)>;
class SLNet
{
public:
	SLNet();
	void Bind(unsigned short port);
	void Connect(const char* address, unsigned short port);
	void SetHook(callback_receive func);
	void NetLoop();
	void Send(unsigned short packet_id, BitStream bitstream, const char* address, unsigned short port, unsigned char priority);
	void Send(unsigned short packet_id, BitStream bitstream, unsigned char priority);
	void SetPrefix(const char* val);
private:
	bool is_connected = false;
	bool is_client = false;
	
	WSASession ws_session;
	UDPSocket ws_socket;
	sockaddr_in ws_peer;
	
	callback_receive receive_t{};

	char prefix[20] = { 0 };
	int prefix_len = 0;

	unsigned char used_id_last = 0;
	unsigned long used_ids[20] = { 0 };

	unsigned long last_sent = 0;
};

