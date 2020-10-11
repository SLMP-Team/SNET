#include "Socket.hpp"

#if defined(_WIN32)

WSASession::WSASession()
{
	int ret = WSAStartup(MAKEWORD(2, 2), &ws_data);
	if (ret != 0) printf("WinSock Initalization Error!\n");
}


WSASession::~WSASession()
{
	WSACleanup();
}

UDPSocket::UDPSocket()
{
	ws_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (ws_socket == INVALID_SOCKET) printf("Socket Initalization Error!\n");
}

UDPSocket::~UDPSocket()
{
	closesocket(ws_socket);
}

void UDPSocket::SendTo(const char* address, unsigned short port, const char* buffer, int len, int flags)
{
	sockaddr_in add;
	
	add.sin_family = AF_INET;
	add.sin_addr.s_addr = inet_addr(address);
	add.sin_port = htons(port);

	sendto(ws_socket, buffer, len, flags, reinterpret_cast<SOCKADDR*>(&add), sizeof(add));
}

void UDPSocket::SendTo(sockaddr_in& address, const char* buffer, int len, int flags) 
{
	sendto(ws_socket, buffer, len, flags, reinterpret_cast<SOCKADDR*>(&address), sizeof(address));
}

sockaddr_in UDPSocket::RecvFrom(char* buffer, int len, int &real_size, int flags)
{
	sockaddr_in from;

	int size = sizeof(from);
	real_size = recvfrom(ws_socket, buffer, len, flags, reinterpret_cast<SOCKADDR*>(&from), &size);

	return from;
}

void UDPSocket::Bind(unsigned short port) 
{
	sockaddr_in add;
	
	add.sin_family = AF_INET;
	add.sin_addr.s_addr = htonl(INADDR_ANY);
	add.sin_port = htons(port);

	int ret = bind(ws_socket, reinterpret_cast<SOCKADDR*>(&add), sizeof(add));
	if (ret != 0) printf("Socket Binding Error!\n");

	DWORD nonBlocking = 1;
	ret = ioctlsocket(ws_socket, FIONBIO, &nonBlocking);
	if (ret != 0) printf("Non-Blocking Mode Error!\n");
}

#endif