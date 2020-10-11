#include "SLNet.hpp"

SLNet pNet;

void on_receive(unsigned int packet_id, BitStream bitstream, const char* addr, unsigned int port)
{
	//std::cout << addr << ":" << port << " => " << msg << std::endl;
	printf("New Message From %s:%d With ID %d\n", addr, port, packet_id);
	unsigned char param = bitstream.read<unsigned char>();
	unsigned char param2 = bitstream.read<unsigned char>();
	printf("%d %d\n", param, param2);

	std::string result(param2, '\0');
	bitstream.read(const_cast<char*>(result.data()), result.size());

	printf("%s\n", result.c_str());
	pNet.Send(2, bitstream, addr, port, 0);
}

int main()
{
	pNet.Bind(6666);
	pNet.SetHook(on_receive);
	pNet.SetPrefix("EXMPL");

	while (1)
		pNet.NetLoop();

	return 0;
}