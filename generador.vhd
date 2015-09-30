-- This VHDL application uses processes to generate 3 types of digital signals (triangular, saw-tooth, and sine) with FPGA hardware.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.all;

ENTITY generador IS
	
	PORT
	(
		AB 		: OUT STD_LOGIC; 					-- Señal A/B
		DIGIT	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Palabra digital
		CS 		: OUT STD_LOGIC; 					-- Señal CS
		WR 		: OUT STD_LOGIC; 					-- Señal WR
		LDAC 	: OUT STD_LOGIC; 					-- Señal LDAC
		TIPO 	: IN  STD_LOGIC_VECTOR(1 DOWNTO 0); -- Selector de forma de señal
		AMP 	: IN  STD_LOGIC_VECTOR(1 DOWNTO 0); -- Selector de amplitud de señal
		FREC 	: IN  STD_LOGIC_VECTOR(1 DOWNTO 0); -- Selector de frecuencia de señal
		CLK_INT : IN  STD_LOGIC; 					-- Reloj de 25.175 MHz
		CLEAR	: OUT STD_LOGIC						--Señal CLR
	);
	END generador;
	
	ARCHITECTURE dcse OF generador IS
		CONSTANT	MAX	: INTEGER := 25175;	 -- Valor máximo del contador que genera la señal de muestreo
											 -- dado el oscilador interno
		SIGNAL		muestreo : STD_LOGIC:= '0';	-- Señal de muestreo que determina cada cuánto tiempo 
												-- varío la señal analógica de salida
		SIGNAL		INC	: STD_LOGIC := '0';	-- Señal que usaremos para ver si debo o no incrementar 
											-- la señal en el diente de sierra (para que tenga la misma
											-- frecuencia que las demás y no el doble)
		SIGNAL		k :	INTEGER		:= 0;	-- Contador para la señal de muestreo
		SIGNAL		n : INTEGER RANGE 0 TO 255;			 
		SIGNAL		ValorDigit : INTEGER RANGE 0 TO 5100 := 0;-- Señal digital que introduzco en el convertidor
															  -- para generar la señal analógica
		SIGNAL		SumRes	:	STD_LOGIC:='0';	-- Señal que indica si debo sumar o restar 
												-- (para la señal triangular)
		SIGNAL		ampMax	:	INTEGER;		-- Señal que nos determina cuál es la amplitud de la señal
		SIGNAL		divisor	:	INTEGER;
		SIGNAL		comp	:	INTEGER;		-- Señal que marca el límite a comparar para así 
												-- generar señales de diferentes frecuencias
		SIGNAL		seno	:	INTEGER RANGE 0 TO 255;	-- Valor de la señal armónica, entre 0 y 255
		SIGNAL		resultado :	INTEGER RANGE 0 TO 255;	-- Resultado final a mostrar por la salida digital 
														-- (que deberá ser pasado de entero a vector de bits)
	
	BEGIN
	
	AB <= '0';	 -- Elegimos el canal A para sacar las señales
	LDAC <= '0'; -- LDAC permanentemente a 0
	CLEAR <= '1'; -- CLR permanentemente inactiva (a 1)

	-- Proceso para seleccionar la amplitud de la señal
	PROCESS(AMP)
		BEGIN
		CASE AMP IS
			WHEN "00"	=> ampMax <= 51;	-- 1 voltio 
			WHEN "01"	=> ampMax <= 102;	-- 2 voltios
			WHEN "10"	=> ampMax <= 153;	-- 3 voltios
			WHEN "11"	=> ampMax <= 255;	-- 5 voltios
			WHEN OTHERS	=> ampMax <= 0;		-- 0 voltios
		END CASE;
	END PROCESS;
	PROCESS(AMP)
		BEGIN
		CASE AMP IS
			WHEN "00"	=> divisor <= 50;	-- 1 voltio 
			WHEN "01"	=> divisor <= 25;	-- 2 voltios
			WHEN "10"	=> divisor <= 17;	-- 3 voltios
			WHEN "11"	=> divisor <= 10;	-- 5 voltios
			WHEN OTHERS	=> divisor <= 1;		-- 0 voltios
		END CASE;
	END PROCESS;
	
	-- Procesor para elegir la frecuencia de la señal
	PROCESS(FREC)
		BEGIN
		CASE FREC IS
			WHEN "00"	=> comp <= 393;	-- 62.5 Hz
			WHEN "01"	=> comp <= 197;	-- 125 Hz
			WHEN "10"	=> comp <= 98;	-- 250 Hz
			WHEN "11"	=> comp <= 49;-- Muestreo de 512kHz -> 25.175MHz/512kHz = 49.1699 (500 Hz)
			WHEN OTHERS	=> comp <= 49;-- Muestreo de 512kHz -> 25.175MHz/512kHz = 49.1699 (500 Hz)
		END CASE;
	END PROCESS;
	
	PROCESS (CLK_INT)
		BEGIN
		-- Cada vez que hay flanco de subida en el generador interno
		IF CLK_INT'event AND CLK_INT='1' THEN
			-- Incremento el contador
			k <= k + 1;
			IF k >= comp THEN
				-- Si sobrepaso el valor para generar la señal de muestreo, la invierto
				muestreo <= NOT muestreo;
				-- Introduzco este valor en CS y WR
				CS <= muestreo;
				WR <= muestreo;
				-- Reinicio el contador
				k <= 0;
			END IF;
		END IF;
	END PROCESS;
	
	
	PROCESS (muestreo)
		BEGIN
		
		IF muestreo'event AND muestreo='0' THEN
			-- Cada vez que deba introducir una muestra en la entrada del convertidor D/A
			-- Varío el valor de la señal que determina si debo o no incrementar el diente de sierra
			INC <= NOT INC;
			IF TIPO = "01" THEN	-- Señal diente de sierra
				IF ValorDigit >= (ampMax*10) THEN
				 -- Si la señal digital genera una salida superior al valor máximo de amplitud por 10
				 -- Multiplico por 10 porque así puedo hacer el mínimo incremento que he definido, que será
				 -- de 0.2 (51/255) en la señal de 1 voltio de amplitud. Si multiplico por 10, el incremento
				 -- será de 2, por lo que sí será apreciable en la variable integer
					IF INC='1' THEN
					  -- Si además está activa la señal INC, es cuando el diente de sierra vuelve a 0 
				      -- al haber alcanzado su máximo
					  ValorDigit <= 0;
					END IF;
				ELSE
					IF INC='1' THEN -- Así se incrementa cada 2 muestras y ocupa el periodo
					  -- Añado el incremento correspondiente (para la amplitud máxima, será 1 de 255), 
					  -- multiplicado por 10
					  ValorDigit <= ValorDigit + 10*ampMax/255;
					END IF;
				END IF;
			-- El resultado es justo la señal dd dividida entre 10
			resultado <= ValorDigit/10;
			END IF;
			
			IF TIPO = "10" THEN	-- Señal triangular
				IF ValorDigit >= ((ampMax-1)*10) THEN
					-- Si sobrepaso el límite superior, activo la señal en modo Resta
					SumRes <= '1';
				END IF;
				IF ValorDigit = 10*ampMax/255 THEN
					-- Si llego al límite inferior, activo la señal en modo Suma
					SumRes <= '0';
				END IF;
				
				IF SumRes = '0' THEN
					-- En modo Suma incremento
					ValorDigit <= ValorDigit + 10*ampMax/255;
				ELSE
					-- En caso contrario decremento
					ValorDigit <= ValorDigit - 10*ampMax/255;
				END IF;
			-- Una vez más, el resultado dividido entre 10
			resultado <= ValorDigit/10;
			END IF;
			
			IF TIPO = "11" THEN	-- Señal senoidal
				IF ValorDigit >= 510 THEN
					-- Si llego al límite 510 (las posibles fases), vuelvo a 0
					ValorDigit <= 0;
				ELSE
					-- En caso contrario, incremento una unidad
					ValorDigit <= ValorDigit + 1;
				END IF;
			-- El resultado es el valor del seno, normalizado según la amplitud máxima
			resultado <= (seno*10/divisor);
			END IF;
			-- En la salida digital muestro resultado
			DIGIT <= CONV_STD_LOGIC_VECTOR(resultado,8);
		END IF;
	END PROCESS;

	WITH ValorDigit SELECT
	-- Según el valor de ValorDigit (que será la fase en este caso), muestro un valor 
	-- u otro del seno entre 0 y 255. El código ha sido generado con Matlab
		seno <= 
				128 WHEN 0,
				129 WHEN 1,
				131 WHEN 2,
				132 WHEN 3,
				134 WHEN 4,
				135 WHEN 5,
				137 WHEN 6,
				138 WHEN 7,
				140 WHEN 8,
				142 WHEN 9,
				143 WHEN 10,
				145 WHEN 11,
				146 WHEN 12,
				148 WHEN 13,
				149 WHEN 14,
				151 WHEN 15,
				152 WHEN 16,
				154 WHEN 17,
				155 WHEN 18,
				157 WHEN 19,
				158 WHEN 20,
				160 WHEN 21,
				162 WHEN 22,
				163 WHEN 23,
				165 WHEN 24,
				166 WHEN 25,
				167 WHEN 26,
				169 WHEN 27,
				170 WHEN 28,
				172 WHEN 29,
				173 WHEN 30,
				175 WHEN 31,
				176 WHEN 32,
				178 WHEN 33,
				179 WHEN 34,
				181 WHEN 35,
				182 WHEN 36,
				183 WHEN 37,
				185 WHEN 38,
				186 WHEN 39,
				188 WHEN 40,
				189 WHEN 41,
				190 WHEN 42,
				192 WHEN 43,
				193 WHEN 44,
				194 WHEN 45,
				196 WHEN 46,
				197 WHEN 47,
				198 WHEN 48,
				200 WHEN 49,
				201 WHEN 50,
				202 WHEN 51,
				203 WHEN 52,
				205 WHEN 53,
				206 WHEN 54,
				207 WHEN 55,
				208 WHEN 56,
				210 WHEN 57,
				211 WHEN 58,
				212 WHEN 59,
				213 WHEN 60,
				214 WHEN 61,
				215 WHEN 62,
				217 WHEN 63,
				218 WHEN 64,
				219 WHEN 65,
				220 WHEN 66,
				221 WHEN 67,
				222 WHEN 68,
				223 WHEN 69,
				224 WHEN 70,
				225 WHEN 71,
				226 WHEN 72,
				227 WHEN 73,
				228 WHEN 74,
				229 WHEN 75,
				230 WHEN 76,
				231 WHEN 77,
				232 WHEN 78,
				233 WHEN 79,
				234 WHEN 80,
				234 WHEN 81,
				235 WHEN 82,
				236 WHEN 83,
				237 WHEN 84,
				238 WHEN 85,
				238 WHEN 86,
				239 WHEN 87,
				240 WHEN 88,
				241 WHEN 89,
				241 WHEN 90,
				242 WHEN 91,
				243 WHEN 92,
				243 WHEN 93,
				244 WHEN 94,
				245 WHEN 95,
				245 WHEN 96,
				246 WHEN 97,
				246 WHEN 98,
				247 WHEN 99,
				248 WHEN 100,
				248 WHEN 101,
				249 WHEN 102,
				249 WHEN 103,
				250 WHEN 104,
				250 WHEN 105,
				250 WHEN 106,
				251 WHEN 107,
				251 WHEN 108,
				252 WHEN 109,
				252 WHEN 110,
				252 WHEN 111,
				253 WHEN 112,
				253 WHEN 113,
				253 WHEN 114,
				253 WHEN 115,
				254 WHEN 116,
				254 WHEN 117,
				254 WHEN 118,
				254 WHEN 119,
				254 WHEN 120,
				255 WHEN 121,
				255 WHEN 122,
				255 WHEN 123,
				255 WHEN 124,
				255 WHEN 125,
				255 WHEN 126,
				255 WHEN 127,
				255 WHEN 128,
				255 WHEN 129,
				255 WHEN 130,
				255 WHEN 131,
				255 WHEN 132,
				255 WHEN 133,
				255 WHEN 134,
				255 WHEN 135,
				254 WHEN 136,
				254 WHEN 137,
				254 WHEN 138,
				254 WHEN 139,
				254 WHEN 140,
				253 WHEN 141,
				253 WHEN 142,
				253 WHEN 143,
				253 WHEN 144,
				252 WHEN 145,
				252 WHEN 146,
				252 WHEN 147,
				251 WHEN 148,
				251 WHEN 149,
				250 WHEN 150,
				250 WHEN 151,
				250 WHEN 152,
				249 WHEN 153,
				249 WHEN 154,
				248 WHEN 155,
				248 WHEN 156,
				247 WHEN 157,
				246 WHEN 158,
				246 WHEN 159,
				245 WHEN 160,
				245 WHEN 161,
				244 WHEN 162,
				243 WHEN 163,
				243 WHEN 164,
				242 WHEN 165,
				241 WHEN 166,
				241 WHEN 167,
				240 WHEN 168,
				239 WHEN 169,
				238 WHEN 170,
				238 WHEN 171,
				237 WHEN 172,
				236 WHEN 173,
				235 WHEN 174,
				234 WHEN 175,
				234 WHEN 176,
				233 WHEN 177,
				232 WHEN 178,
				231 WHEN 179,
				230 WHEN 180,
				229 WHEN 181,
				228 WHEN 182,
				227 WHEN 183,
				226 WHEN 184,
				225 WHEN 185,
				224 WHEN 186,
				223 WHEN 187,
				222 WHEN 188,
				221 WHEN 189,
				220 WHEN 190,
				219 WHEN 191,
				218 WHEN 192,
				217 WHEN 193,
				215 WHEN 194,
				214 WHEN 195,
				213 WHEN 196,
				212 WHEN 197,
				211 WHEN 198,
				210 WHEN 199,
				208 WHEN 200,
				207 WHEN 201,
				206 WHEN 202,
				205 WHEN 203,
				203 WHEN 204,
				202 WHEN 205,
				201 WHEN 206,
				200 WHEN 207,
				198 WHEN 208,
				197 WHEN 209,
				196 WHEN 210,
				194 WHEN 211,
				193 WHEN 212,
				192 WHEN 213,
				190 WHEN 214,
				189 WHEN 215,
				188 WHEN 216,
				186 WHEN 217,
				185 WHEN 218,
				183 WHEN 219,
				182 WHEN 220,
				181 WHEN 221,
				179 WHEN 222,
				178 WHEN 223,
				176 WHEN 224,
				175 WHEN 225,
				173 WHEN 226,
				172 WHEN 227,
				170 WHEN 228,
				169 WHEN 229,
				167 WHEN 230,
				166 WHEN 231,
				165 WHEN 232,
				163 WHEN 233,
				162 WHEN 234,
				160 WHEN 235,
				158 WHEN 236,
				157 WHEN 237,
				155 WHEN 238,
				154 WHEN 239,
				152 WHEN 240,
				151 WHEN 241,
				149 WHEN 242,
				148 WHEN 243,
				146 WHEN 244,
				145 WHEN 245,
				143 WHEN 246,
				142 WHEN 247,
				140 WHEN 248,
				138 WHEN 249,
				137 WHEN 250,
				135 WHEN 251,
				134 WHEN 252,
				132 WHEN 253,
				131 WHEN 254,
				129 WHEN 255,
				128 WHEN 256,
				126 WHEN 257,
				124 WHEN 258,
				123 WHEN 259,
				121 WHEN 260,
				120 WHEN 261,
				118 WHEN 262,
				117 WHEN 263,
				115 WHEN 264,
				113 WHEN 265,
				112 WHEN 266,
				110 WHEN 267,
				109 WHEN 268,
				107 WHEN 269,
				106 WHEN 270,
				104 WHEN 271,
				103 WHEN 272,
				101 WHEN 273,
				100 WHEN 274,
				98 WHEN 275,
				97 WHEN 276,
				95 WHEN 277,
				93 WHEN 278,
				92 WHEN 279,
				90 WHEN 280,
				89 WHEN 281,
				88 WHEN 282,
				86 WHEN 283,
				85 WHEN 284,
				83 WHEN 285,
				82 WHEN 286,
				80 WHEN 287,
				79 WHEN 288,
				77 WHEN 289,
				76 WHEN 290,
				74 WHEN 291,
				73 WHEN 292,
				72 WHEN 293,
				70 WHEN 294,
				69 WHEN 295,
				67 WHEN 296,
				66 WHEN 297,
				65 WHEN 298,
				63 WHEN 299,
				62 WHEN 300,
				61 WHEN 301,
				59 WHEN 302,
				58 WHEN 303,
				57 WHEN 304,
				55 WHEN 305,
				54 WHEN 306,
				53 WHEN 307,
				52 WHEN 308,
				50 WHEN 309,
				49 WHEN 310,
				48 WHEN 311,
				47 WHEN 312,
				45 WHEN 313,
				44 WHEN 314,
				43 WHEN 315,
				42 WHEN 316,
				41 WHEN 317,
				40 WHEN 318,
				38 WHEN 319,
				37 WHEN 320,
				36 WHEN 321,
				35 WHEN 322,
				34 WHEN 323,
				33 WHEN 324,
				32 WHEN 325,
				31 WHEN 326,
				30 WHEN 327,
				29 WHEN 328,
				28 WHEN 329,
				27 WHEN 330,
				26 WHEN 331,
				25 WHEN 332,
				24 WHEN 333,
				23 WHEN 334,
				22 WHEN 335,
				21 WHEN 336,
				21 WHEN 337,
				20 WHEN 338,
				19 WHEN 339,
				18 WHEN 340,
				17 WHEN 341,
				17 WHEN 342,
				16 WHEN 343,
				15 WHEN 344,
				14 WHEN 345,
				14 WHEN 346,
				13 WHEN 347,
				12 WHEN 348,
				12 WHEN 349,
				11 WHEN 350,
				10 WHEN 351,
				10 WHEN 352,
				9 WHEN 353,
				9 WHEN 354,
				8 WHEN 355,
				7 WHEN 356,
				7 WHEN 357,
				6 WHEN 358,
				6 WHEN 359,
				5 WHEN 360,
				5 WHEN 361,
				5 WHEN 362,
				4 WHEN 363,
				4 WHEN 364,
				3 WHEN 365,
				3 WHEN 366,
				3 WHEN 367,
				2 WHEN 368,
				2 WHEN 369,
				2 WHEN 370,
				2 WHEN 371,
				1 WHEN 372,
				1 WHEN 373,
				1 WHEN 374,
				1 WHEN 375,
				1 WHEN 376,
				0 WHEN 377,
				0 WHEN 378,
				0 WHEN 379,
				0 WHEN 380,
				0 WHEN 381,
				0 WHEN 382,
				0 WHEN 383,
				0 WHEN 384,
				0 WHEN 385,
				0 WHEN 386,
				0 WHEN 387,
				0 WHEN 388,
				0 WHEN 389,
				0 WHEN 390,
				0 WHEN 391,
				1 WHEN 392,
				1 WHEN 393,
				1 WHEN 394,
				1 WHEN 395,
				1 WHEN 396,
				2 WHEN 397,
				2 WHEN 398,
				2 WHEN 399,
				2 WHEN 400,
				3 WHEN 401,
				3 WHEN 402,
				3 WHEN 403,
				4 WHEN 404,
				4 WHEN 405,
				5 WHEN 406,
				5 WHEN 407,
				5 WHEN 408,
				6 WHEN 409,
				6 WHEN 410,
				7 WHEN 411,
				7 WHEN 412,
				8 WHEN 413,
				9 WHEN 414,
				9 WHEN 415,
				10 WHEN 416,
				10 WHEN 417,
				11 WHEN 418,
				12 WHEN 419,
				12 WHEN 420,
				13 WHEN 421,
				14 WHEN 422,
				14 WHEN 423,
				15 WHEN 424,
				16 WHEN 425,
				17 WHEN 426,
				17 WHEN 427,
				18 WHEN 428,
				19 WHEN 429,
				20 WHEN 430,
				21 WHEN 431,
				21 WHEN 432,
				22 WHEN 433,
				23 WHEN 434,
				24 WHEN 435,
				25 WHEN 436,
				26 WHEN 437,
				27 WHEN 438,
				28 WHEN 439,
				29 WHEN 440,
				30 WHEN 441,
				31 WHEN 442,
				32 WHEN 443,
				33 WHEN 444,
				34 WHEN 445,
				35 WHEN 446,
				36 WHEN 447,
				37 WHEN 448,
				38 WHEN 449,
				40 WHEN 450,
				41 WHEN 451,
				42 WHEN 452,
				43 WHEN 453,
				44 WHEN 454,
				45 WHEN 455,
				47 WHEN 456,
				48 WHEN 457,
				49 WHEN 458,
				50 WHEN 459,
				52 WHEN 460,
				53 WHEN 461,
				54 WHEN 462,
				55 WHEN 463,
				57 WHEN 464,
				58 WHEN 465,
				59 WHEN 466,
				61 WHEN 467,
				62 WHEN 468,
				63 WHEN 469,
				65 WHEN 470,
				66 WHEN 471,
				67 WHEN 472,
				69 WHEN 473,
				70 WHEN 474,
				72 WHEN 475,
				73 WHEN 476,
				74 WHEN 477,
				76 WHEN 478,
				77 WHEN 479,
				79 WHEN 480,
				80 WHEN 481,
				82 WHEN 482,
				83 WHEN 483,
				85 WHEN 484,
				86 WHEN 485,
				88 WHEN 486,
				89 WHEN 487,
				90 WHEN 488,
				92 WHEN 489,
				93 WHEN 490,
				95 WHEN 491,
				97 WHEN 492,
				98 WHEN 493,
				100 WHEN 494,
				101 WHEN 495,
				103 WHEN 496,
				104 WHEN 497,
				106 WHEN 498,
				107 WHEN 499,
				109 WHEN 500,
				110 WHEN 501,
				112 WHEN 502,
				113 WHEN 503,
				115 WHEN 504,
				117 WHEN 505,
				118 WHEN 506,
				120 WHEN 507,
				121 WHEN 508,
				123 WHEN 509,
				124 WHEN 510,
				126 WHEN 511,
				0	WHEN OTHERS;
END dcse;
