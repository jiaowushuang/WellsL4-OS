#include <types_def.h>
#include <sys/errno.h>
#include <sys/util.h>

sword_t char2hex(char c, byte_t *x)
{
	if (c >= '0' && c <= '9') 
	{
		*x = c - '0';
	} 
	else if (c >= 'a' && c <= 'f')
	{
		*x = c - 'a' + 10;
	} 
	else if (c >= 'A' && c <= 'F') 
	{
		*x = c - 'A' + 10;
	} 
	else 
	{
		return -EINVAL;
	}

	return 0;
}

sword_t hex2char(byte_t x, char *c)
{
	if (x <= 9)
	{
		*c = x + '0';
	} 
	else  if (x >= 10 && x <= 15)
	{
		*c = x - 10 + 'a';
	} 
	else
	{
		return -EINVAL;
	}

	return 0;
}

size_t bin2hex(const byte_t *buf, size_t buflen, char *hex, size_t hexlen)
{
	if ((hexlen + 1) < buflen * 2)
	{
		return 0;
	}

	for (size_t i = 0; i < buflen; i++) 
	{
		if (hex2char(buf[i] >> 4, &hex[2 * i]) < 0) 
		{
			return 0;
		}
		if (hex2char(buf[i] & 0xf, &hex[2 * i + 1]) < 0)
		{
			return 0;
		}
	}

	hex[2 * buflen] = '\0';
	return 2 * buflen;
}

size_t hex2bin(const char *hex, size_t hexlen, byte_t *buf, size_t buflen)
{
	byte_t dec;

	if (buflen < hexlen / 2 + hexlen % 2) 
	{
		return 0;
	}

	/* if hexlen is uneven, insert leading zero nibble */
	if (hexlen % 2)
	{
		if (char2hex(hex[0], &dec) < 0) 
		{
			return 0;
		}
		buf[0] = dec;
		hex++;
		buf++;
	}

	/* regular hex conversion */
	for (size_t i = 0; i < hexlen / 2; i++) 
	{
		if (char2hex(hex[2 * i], &dec) < 0) 
		{
			return 0;
		}
		buf[i] = dec << 4;

		if (char2hex(hex[2 * i + 1], &dec) < 0) 
		{
			return 0;
		}
		buf[i] += dec;
	}

	return hexlen / 2 + hexlen % 2;
}
