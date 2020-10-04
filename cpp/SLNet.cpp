#include "SLNet.hpp"

void SLNet::Bind(unsigned short port)
{
	if (is_connected)
	{
		printf("SL:NET is already connected!\n");
		return;
	}

	is_connected = true;
	is_client = false;

	ws_socket.Bind(port);
}

void SLNet::Connect(const char* address, unsigned short port)
{
	if (is_connected)
	{
		printf("SL:NET is already connected!\n");
		return;
	}

	is_connected = true;
	is_client = true;

	ws_socket.Bind(0); // any port and any address

	ws_peer.sin_family = AF_INET;
	ws_peer.sin_addr.s_addr = inet_addr(address);
	ws_peer.sin_port = htons(port);
}

void SLNet::SetHook(callback_receive func)
{
	receive_t = func;
}

void SLNet::SetPrefix(const char* val)
{
	memset(prefix, 0, sizeof(prefix));

	prefix_len = strlen(val);
	memcpy(prefix, val, prefix_len);
}

void SLNet::NetLoop()
{
	char buffer[1024];
	int real_size = 0;

	memset(buffer, 0, sizeof(buffer));

	sockaddr_in from = ws_socket.RecvFrom(buffer, sizeof(buffer), real_size);
	if (real_size > 0 && real_size >= prefix_len)
	{
		char addr[INET_ADDRSTRLEN];
		
		inet_ntop(AF_INET, &(from.sin_addr), addr, INET_ADDRSTRLEN);
		unsigned int port = ntohs(from.sin_port);

		if (std::string(buffer, prefix_len).compare(std::string(prefix, prefix_len)) == 0)
		{
			std::string clear_data(buffer, real_size);
			clear_data = clear_data.substr(prefix_len);
			
			BitStream bitstream;
			bitstream.SetData((const unsigned char*)clear_data.c_str(), clear_data.length());
			bitstream.SetData(reinterpret_cast<const unsigned char*>(clear_data.c_str()), clear_data.length());

			auto unique_id = bitstream.Read<unsigned long>();
			printf("%d\n", unique_id);

			receive_t(0, bitstream, addr, port);
		}
	}
}

void SLNet::Send(BitStream* bitstream, const char* address, unsigned short port)
{
	if (!is_connected || is_client) return;

	unsigned char* data = bitstream->GetData();
	size_t data_len = bitstream->GetDataLen();

	ws_socket.SendTo(address, port, reinterpret_cast<const char*>(data), data_len);
}

void SLNet::Send(BitStream* bitstream)
{
	if (!is_connected || !is_client) return;

	unsigned char* data = bitstream->GetData();
	size_t data_len = bitstream->GetDataLen();

	ws_socket.SendTo(ws_peer, reinterpret_cast<const char*>(data), data_len);
}