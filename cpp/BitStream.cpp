#include "BitStream.hpp"
#pragma warning(disable: 6308)

void BitStream::SetDataLen(size_t len)
{
	if (!data)
	{
		data = static_cast<unsigned char*>(malloc(len));
		if (!data) assert("malloc returned nullptr");
	}
	else
	{
		data = static_cast<unsigned char*>(realloc(data, len));
		if (!data) assert("realloc returned nullptr");
	}
	data_len = len;
}

void BitStream::SetData(const unsigned char* temp_data, const size_t len)
{
	SetDataLen(len);
	memcpy(data, temp_data, len);
}

void BitStream::AddBytesToData(size_t len)
{
	if (!data)
		return SetDataLen(len);
	data = static_cast<unsigned char*>(realloc(data, data_len + len));
	if (!data) assert("realloc returned nullptr");
	data_len += len;
}

void BitStream::Read(unsigned char* temp_data, const size_t len)
{
	assert(data && temp_data && len + read_pointer <= data_len);
	memcpy(temp_data, data + read_pointer, len);
	read_pointer += len;
}

void BitStream::Write(unsigned char* temp_data, const size_t len)
{
	AddBytesToData(len);
	memcpy(data + write_pointer, temp_data, len);
	write_pointer += len;
}