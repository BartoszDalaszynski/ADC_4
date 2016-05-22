'program testowy komunikacji na magistarli RS485
'znaki nadane w terminalu na jednym komputerze s� wysy�ane gdy adres odbiorcy 0
'wpisuj�c znaki najpierw wpisa� dwa znaki adresu, potem tekst do wys�ania i enter

'zadania:
'1. w procedurze odbioru wprowadzi� weryfikacj� adresu zawartego w BOF,
'2. wprowadzi� EOF,
'3. wprowadzi� automatyczne odpowiedzi ramk� potwierdzenia odbioru,
'4. zastosowa� przerwanie UDRE1,
'5. wprowadzi� dwudzielno�� bufora tabin(), jedna po�owa s�uzy do nadawania,
'a druga do odbioru znak�w lub wprowadzi� bufor pier�cieniowy.

'by Marcin Kowalczyk

'obliczenia parametr�w konfiguracyjnych
Const Prescfc = 0                                           'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'cz�stotliwo�� po przeskalowaniu
'sta�e konfiguracujne USART�w
Const Baundrs0 = 115200                                     'pr�dko�� transmisji po RS [bps] USART0
Const _ubrr0 =(((fcrystal / Baundrs0) / 16) - 1)            'potrzebne w nast�pnych zadaniach
Const Baundrs1 = Baundrs0                                   'pr�dko�� transmisji po RS [bps] USART1
Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)            'potrzebne w nast�pnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"                                   'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zb�dne gdy inicjalizacja w zdefiniowanej procedurze


'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Te_pin Alias 4
Te Alias Portd.te_pin                                       'sterowanie przep�ywem w nadajniku/odbiorniku linii

Led_pin Alias 5
Led Alias Portd.led_pin


'Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
'Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki


'DEFINICJA ADC
'Ldi rstemp,0
'!out ddrA,rstemp
'Ldi rstemp, 2
'!out porta,rstemp

'LDI rstemp, &B11100001
'!OUT ADMUX, rstemp

'LDI rstemp, &B10000000
'!OUT ADCSRA, rstemp



'auto ADC
Config Adc = Single , Prescaler = Auto , Reference = Avcc

'Dim W As Word , Channel As Byte
'Channel = 0


'odpalenie timera
Config Timer1 = Timer , Prescale = 64

On Timer1 Oblicz_adc
Timer1 = 100

Enable  TIMER1







On Urxc1 Usart_rx Nosave                                    'deklaracja przerwania URXC (odbi�r znaku USART)
On Utxc1 Usart_tx_end Nosave                                'deklaracja przerwania UTXC, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w�asny
Dim Adro As Byte
Dim Bajt As Byte
Adrw = 1                                                    'adres odbiorcy 0...15
Const Bof_bit = &B11000000
Const Bofm_bit = &B10000001
Const Bofmaster_bit = &B11000010
Const Bofs_bit = &B11000001

Const Eofs_bit = &B10000001
Const Eofm_bit = &B10100010

Dim Stanodbioru As Byte
Stanodbioru = 0

SBI Ddrd,Led_pin

rcall usart_init                                            'inicjalizacja USART�w i w��czenie przerwa�
Sei                                                         'w��czenie globalnie przerwa�


Do
   sbi adcsra,6
'   W = Getadc(channel)
'   Waitms 1000
'   Print "Channel " ; Channel ; " value " ; W

   !petla_adc:
   SBIC ADCSRA, 4
      RJMP petla_ADC
   Waitms 1500
   rcall dioda
   Print "ADC: " ; Adc


Loop

Oblicz_adc:
   Print "LICZNIK"
Return


'ZMIANA ZMIANA

Usart_rx:                                                   'etykieta bascomowa koniecznie bez !
   push rstemp                                              'o ile potrzeba - sprawdzi�
   in rstemp,sreg                                           'o ile potrzeba  - sprawdzi�
   push rstemp                                              'o ile potrzeba - sprawdzi�
   push rsdata                                              'o ile potrzeba  - sprawdzi�
   push yl                                                  'o ile potrzeba  - sprawdzi�
   push yh                                                  'o ile potrzeba  - sprawdzi�
   push r1                                                  'o ile potrzeba  - sprawdzi�
   push r0                                                  'o ile potrzeba  - sprawdzi�
   !cli
   rcall rs_rx                                              'kod mo�e by� bezpo�renio w usart_rx
   sei
   'odtworzenie stanu jak przed przerwanie
   pop r0
   pop r1
   pop yh
   pop yl
   pop rsdata
   pop rstemp
   !out sreg,rstemp
   pop rstemp
Return
                                             '

!rs_rx:
   in rsdata,udr1
   lDs rstemp, {stanodbioru}
   cpi rstemp,1
      breq koniec_ramki
   cpi rsdata,bofm_bit
      sbis sreg,1
   ret

   ldi rstemp,1
   sts {stanodbioru},rstemp
  ret

   !koniec_ramki:
     cpi rsdata, eofm_bit
      sbis sreg,1
     Ret
      ldi rstemp,0
      sts {stanodbioru},rstemp

      Te = 1
      ldi rstemp,bofmaster_bit
      !out udr1,rstemp

      ldi rstemp,40
      !wyslij_liczby:

      !pusty_UDR:
      sbiS ucsr1a,udre1                                     'petla gdy udre1 jest zajety
      rjmp pusty_UDR

      !out udr1,rstemp
      inc rstemp
      cpi rstemp,120
         brne wyslij_liczby

      !pusty_UDR1:
      sbiS ucsr1a,udre1                                     'petla gdy udre1 jest zajety
      rjmp pusty_UDR1

      ldi rstemp,eofs_bit
      !out udr1,rstemp
   ret




Usart_tx_end:                                               'przerwanie wyst�pi gdy USART wy�le znak i UDR b�dzie pusty
   Te = 0                                                   'wy��czenie nadajnika, w��czenie odbiornika
   'to samo co CBI PORTD,TE_pin, brak zmian w SREG
Return



!usart_init:
'procedura inicjalizacji USART�w
   ldi temp,0
   !out ubrr0h,temp                                         'bardziej znacz�cy bajt UBRR USART0
   !out ubrr1h,temp
   ldi temp,_ubrr0
   !out ubrr0l,temp                                         'mniej znacz�cy bajt UBRR USART0
   ldi temp,_ubrr1
   !out ubrr1l,temp                                         'mniej znacz�cy bajt UBRR USART1
   ldi temp,24                                              'w��czone odbiorniki i nadajniki USART�w
   !out ucsr0b,temp
   !out ucsr1b,temp
   ldi temp,6                                               'N8bit
   !out ucsr0C,temp
   !out ucsr1C,temp
   'ustawienia RS485
   Te = 0                                                   'domy�lnie stan odbioru
   sbi ddrd,Te_pin                                          'wyj�cie TE silnopr�dowe
   'w��czenie przerwa�
   Enable Urxc
   Enable Urxc1
   Enable Utxc1
ret

!dioda:
            Sbis portd,led_pin
      rjmp zapal_led
   sbic portd,led_pin
      rjmp zgas_led
   !zapal_led:
      Led = 1
      rjmp wyslij
   !zgas_led:
      Led = 0
      !wyslij:
      ret