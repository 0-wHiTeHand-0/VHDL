-- This application calculates the differential electric voltage between two points, showing the output in two 7-segment displays. The hardware to use this, is a FPGA with an AD (analog to digital converter) expansion kit.


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
Use ieee.std_logic_arith.All;
Use ieee.std_logic_unsigned.All;

ENTITY voltimetro IS
	PORT (
			display1 		: OUT STD_LOGIC_VECTOR(6 DOWNTO 0); 	
			-- unidades en el display de 7seg
			display2 		: OUT STD_LOGIC_VECTOR(6 DOWNTO 0);		
			-- decenas en el display de 7seg
			display_punto	: OUT STD_LOGIC;						
			-- punto decimal en el display de 7seg
			selector		: OUT STD_LOGIC_VECTOR(2 DOWNTO 0); 	
			-- selector de entrada a convertir
			mode 			: OUT STD_LOGIC;						
			-- señal para el tipo de funcionamiento del conversor
			cs				: OUT STD_LOGIC;						
			-- señal de control del conversor
			rd				: OUT STD_LOGIC;						
			-- señal de control del conversor
			
			digin			: IN  STD_LOGIC_VECTOR(7 DOWNTO 0); 	
			-- entrada digital
			int				: IN  STD_LOGIC;						
			-- señal de control del conversor
			clk				: IN  STD_LOGIC							
			-- reloj de la placa
			
	);
	
END voltimetro;

ARCHITECTURE voltimetro OF voltimetro IS

SIGNAL leer	: STD_LOGIC;						-- señal auxiliar para controlar cs y rd
SIGNAL cont_clk: INTEGER range 0 to 25200;		-- contador del reloj de la placa

SIGNAL voltaje	: STD_LOGIC_VECTOR(7 DOWNTO 0);	-- valor digital del voltaje
SIGNAL volt_unidades: INTEGER range 0 to 9;		-- cifra unidades del voltaje
SIGNAL volt_decenas: INTEGER range 0 to 9;		-- cifra decenas del voltaje

BEGIN

	-- Invierte la señal leer cada milisegundo
	proceso_reloj: PROCESS (clk)
	BEGIN
	
		IF clk'event AND clk='1' THEN
			cont_clk<=cont_clk+1;  
			IF cont_clk>=25175 THEN
				leer<=NOT leer;    
				cont_clk<= 0;
			END IF;
		END IF;
		
	
	END PROCESS;

	-- Seleccionamos el MODE_0 de operacion del conversor
	mode<='0';
	-- Seleccionamos la entrada analógica 0
	selector<="000";
	-- Al asignar el valor de leer a cs y rd, cada vez que estas dos señales se pongan
	-- a cero se indica al conversor que se debe efectuar la conversion
	cs<=leer;
	rd<=leer;
	-- Queremos mostrar el punto decimal en el display
	display_punto <='1';
	
	-- Cuando se produce un flanco de bajada en int significa que la conversion se ha
	-- efectuado correctamente y el valor digital de voltaje está listo en la entrada 
	proceso_escribir: PROCESS (int)
	BEGIN
		IF int'event AND int='0' THEN
			-- calculamos la conversion a voltios sobre la marcha
			-- las unidades son decivoltios
			volt_unidades <= (((conv_integer(digin))*50)/255)/10;
			-- las decenas son voltios
			volt_decenas <= (((conv_integer(digin))*50)/255) mod 10;
			
		END IF;
	
	END PROCESS;
	
	-- mostramos los valores digitales obtenidos por los displays
	proceso_mostrar: PROCESS(volt_unidades,volt_decenas)
	BEGIN
		CASE(volt_unidades) IS
						
				WHEN 0 => display1 <= "1000000";  --0
				WHEN 1 => display1 <= "1111001";  --1
				WHEN 2 => display1 <= "0100100";  --2
				WHEN 3 => display1 <= "0110000";  --3
				WHEN 4 => display1 <= "0011001";  --4
				WHEN 5 => display1 <= "0010010";  --5
				WHEN 6 => display1 <= "0000010";  --6
				WHEN 7 => display1 <= "1111000";  --7
				WHEN 8 => display1 <= "0000000";  --8
				WHEN 9 => display1 <= "0011000";  --9
				WHEN OTHERS => display1 <= "0111111";  --resto
				
			END CASE;
						
			CASE(volt_decenas) IS
			
				WHEN 0 => display2 <= "1000000";  --0
				WHEN 1 => display2 <= "1111001";  --1
				WHEN 2 => display2 <= "0100100";  --2
				WHEN 3 => display2 <= "0110000";  --3
				WHEN 4 => display2 <= "0011001";  --4
				WHEN 5 => display2 <= "0010010";  --5
				WHEN 6 => display2 <= "0000010";  --6
				WHEN 7 => display2 <= "1111000";  --7
				WHEN 8 => display2 <= "0000000";  --8
				WHEN 9 => display2 <= "0011000";  --9
				WHEN OTHERS => display2 <= "0111111";  --resto
				
			END CASE;
			
			
			
		END PROCESS;


END voltimetro;
