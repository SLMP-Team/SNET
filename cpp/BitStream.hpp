// by imring
#pragma once

#include <vector>
#include <string>

class BitStream {
public:
	BitStream(const char* _data, const size_t len) { set_data(_data, len); }
	BitStream() = default;

	void set_data(const char* _data, const size_t len) {
		data.resize(len);
		memcpy(data.data(), _data, len);
	}

	inline const unsigned char* get_data() const { return data.data(); }
	inline size_t get_data_size() const { return data.size(); }
	inline void set_data_size(const size_t size) { data.resize(size); }

	template<typename T>
	inline T read() {
		T value;
		read(&value, sizeof(T));
		return value;
	}

	void read(void* _data, const size_t len) {
		//assert(_data && len + read_pointer <= data.size());
		try {
			if (_data && len + read_pointer > data.size()) 
				throw data.size();
			else if (_data != NULL)
			{
				memcpy(_data, data.data() + read_pointer, len);
				read_pointer += len;
			}
		}
		catch(size_t data_size) {
			printf("Data Size is Out of Range: %d", data_size);
		}
	}

	template<typename T>
	inline void write(T value) { write(&value, sizeof(T)); }

	void write(const void* _data, const size_t len) {
		data.resize(data.size() + len);
		memcpy(data.data() + write_pointer, _data, len);
		write_pointer += len;
	}

	size_t read_pointer = 0;
	size_t write_pointer = 0;
private:
	std::vector<unsigned char> data;
};
