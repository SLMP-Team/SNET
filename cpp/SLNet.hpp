#pragma once
#define _WINSOCK_DEPRECATED_NO_WARNINGS

#include "BitStream.hpp"
#if defined(_WIN32)
#include "Socket.hpp"
#else
// fuck no Linux Socket now
#endif

using callback_receive = std::function<void(unsigned int, BitStream, const char*, unsigned int)>;
class SLNet
{
public:
	void Bind(unsigned short port);
	void Connect(const char* address, unsigned short port);
	void SetHook(callback_receive func);
	void NetLoop();
	void Send(BitStream* bitstream, const char* address, unsigned short port);
	void Send(BitStream* bitstream);
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
};

