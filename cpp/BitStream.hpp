#pragma once
#include <vector>
#include <assert.h>

class BitStream
{
public:
	//BitStream(const unsigned char* tmp_data, const size_t len) { SetData(tmp_data, len); }

	void SetDataLen(size_t len);
	void SetData(const unsigned char* tmp_data, const size_t len);

	inline unsigned char* GetData() const { return data; }
	inline size_t GetDataLen() const { return data_len; }

	template<typename T>
	T Read();
	void Read(unsigned char* tmp_data, const size_t len);

	template<typename T>
	void Write(T value);
	void Write(unsigned char* tmp_data, const size_t len);
private:
	size_t read_pointer = 0;
	size_t write_pointer = 0;
	size_t data_len = 0;
	unsigned char* data = nullptr;
	
	void AddBytesToData(size_t len);
};

template<typename T>
T BitStream::Read()
{
	T value;
	Read(&value, sizeof(T));
	return value;
}

template<typename T>
void BitStream::Write(T value)
{
	Write(&value, sizeof(T));
}