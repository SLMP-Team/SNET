#pragma once
#define _CRT_SECURE_NO_WARNINGS

#if not defined(_WIN32)

#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>


class WSASession
{
public:
	WSASession();
	~WSASession();
};

class UDPSocket
{
public:
	UDPSocket();
	~UDPSocket();
	void SendTo(const char* address, unsigned short port, const char* buffer, int len, int flags = 0);
	void SendTo(sockaddr_in& address, const char* buffer, int len, int flags = 0);
	sockaddr_in RecvFrom(char* buffer, int len, int& real_size, int flags = 0);
	void Bind(unsigned short port);
private:
	SOCKET ws_socket;
};

#endif