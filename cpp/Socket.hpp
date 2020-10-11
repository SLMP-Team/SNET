#pragma once

#if defined(_WIN32)

#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS

#pragma comment(lib,"Ws2_32.lib")

#include <WinSock2.h>
#include <WS2tcpip.h>
#include <string>
#include <iostream>
#include <functional>

class WSASession
{
public:
	WSASession();
	~WSASession();
private:
	WSAData ws_data;
};

class UDPSocket
{
public:
	UDPSocket();
	~UDPSocket();
	void SendTo(const char* address, unsigned short port, const char* buffer, int len, int flags = 0);
	void SendTo(sockaddr_in& address, const char* buffer, int len, int flags = 0);
	sockaddr_in RecvFrom(char* buffer, int len, int &real_size, int flags = 0);
	void Bind(unsigned short port);
private:
	SOCKET ws_socket;
};

#endif