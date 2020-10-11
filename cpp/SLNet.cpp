#include "SLNet.hpp"

SLNet::SLNet()
{
	for (int i = 0; i < 20; i++)
		used_ids[i] = 9999;
}

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
			
			BitStream bitstream(clear_data.c_str(), clear_data.length());

			unsigned long unique_id = bitstream.read<unsigned long>();
			unsigned short packet_id = bitstream.read<unsigned short>();
			unsigned char priority = bitstream.read<unsigned char>();

			size_t clear_size = sizeof(unsigned long) + sizeof(unsigned short) + 1;
			bitstream.set_data(clear_data.substr(clear_size).c_str(), clear_data.length() - 1);
			
			bitstream.read_pointer = 0;
			bitstream.write_pointer = 0;

			bool in_use = false;
			for (int a = 0; a < 20; a++)
			{
				if (used_ids[a] == unique_id)
				{
					in_use = true;
					break;
				}
			}

			used_ids[used_id_last] = unique_id;
			used_id_last++;
			if (used_id_last >= 20)
				used_id_last = 0;

			if (priority > 0)
			{
				BitStream conf;
				conf.write<unsigned long>(unique_id);
				if (is_client) Send(0, conf, 0);
				else Send(0, conf, addr, port, 0);
			}

			if (!in_use && packet_id > 0)
				receive_t(packet_id, bitstream, addr, port);
		}
	}
}

void SLNet::Send(unsigned short packet_id, BitStream bitstream, const char* address, unsigned short port, unsigned char priority)
{
	if (!is_connected || is_client) return;

	BitStream _data;
	_data.write<unsigned long>(last_sent);
	_data.write<unsigned short>(packet_id);
	_data.write<unsigned char>(priority);
	
	bitstream.read_pointer = 0;
	std::string a(bitstream.get_data_size(), '\0');
	bitstream.read(const_cast<char*>(a.data()), a.size());

	_data.write(a.data(), a.size());
	
	std::string b(_data.get_data_size(), '\0');
	_data.read_pointer = 0;
	_data.read(const_cast<char*>(b.data()), b.size());

	b = prefix + b;
	ws_socket.SendTo(address, port, b.c_str(), b.length());
}

void SLNet::Send(unsigned short packet_id, BitStream bitstream, unsigned char priority)
{
	if (!is_connected || !is_client) return;

	BitStream _data;
	_data.write<unsigned long>(last_sent);
	_data.write<unsigned short>(packet_id);
	_data.write<unsigned char>(priority);

	bitstream.read_pointer = 0;
	std::string a(bitstream.get_data_size(), '\0');
	bitstream.read(const_cast<char*>(a.data()), a.size());

	_data.write(a.data(), a.size());

	std::string b(_data.get_data_size(), '\0');
	_data.read_pointer = 0;
	_data.read(const_cast<char*>(b.data()), b.size());

	b = prefix + b;
	ws_socket.SendTo(ws_peer, b.c_str(), b.length());
}