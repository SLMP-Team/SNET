#include "UNIXSock.h"

#if not defined(_WIN32)

WSASession::WSASession() { return; }
WSASession::~WSASession() { return; }

UDPSocket::UDPSocket()
{
	ws_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (ws_socket == INVALID_SOCKET) printf("Socket Initalization Error!\n");
}

UDPSocket::~UDPSocket() { close(ws_socket); }

void UDPSocket::SendTo(const char* address, unsigned short port, const char* buffer, int len, int flags)
{
	sockaddr_in add;

	add.sin_family = AF_INET;
	add.sin_addr.s_addr = inet_addr(address);
	add.sin_port = htons(port);

	sendto(ws_socket, buffer, len, flags, reinterpret_cast<SOCKADDR*>(&add), sizeof(add));
}

void UDPSocket::SendTo(sockaddr_in & address, const char* buffer, int len, int flags)
{
	sendto(ws_socket, buffer, len, flags, reinterpret_cast<SOCKADDR*>(&address), sizeof(address));
}

sockaddr_in UDPSocket::RecvFrom(char* buffer, int len, int& real_size, int flags)
{
	sockaddr_in from;

	socklen_t size = sizeof(from);
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

	int nonBlocking = 1;
	if (fcntl(handle, F_SETFL, O_NONBLOCK, nonBlocking) == -1)
		printf("failed to set non-blocking socket\n");
}

#endif