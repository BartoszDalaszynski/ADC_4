Const Prescfc = 0                                           'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'cz�stotliwo�� po przeskalowaniu
'sta�e konfiguracujne USART�w
Const Baundrs0 = 115200                                     'pr�dko�� transmisji po RS [bps] USART0
Const _ubrr0 =(((fcrystal / Baundrs0) / 16) - 1)            'potrzebne w nast�pnych zadaniach
Const Baundrs1 = Baundrs0                                   'pr�dko�� transmisji po RS [bps] USART1
Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)            'potrzebne w nast�pnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"                                   'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal                                         ' informuje program jaka jest cz�stotliwo�� taktowania


'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Te_pin Alias 4
Te Alias Portd.te_pin                                       'sterowanie przep�ywem w nadajniku/odbiorniku linii


Licznik Alias R20                                           'doliczanie do 16 operacji
Config Adc = Single , Prescaler = Auto , Reference = Avcc   'Reference off - z mikro (chyba), Avcc - napi�cie zasilania

Config Timer1 = Timer , Prescale = 1024 , Compare A = Disconnect , Clear Timer = 1       'konfiguracja timera
Stop Timer1
Ocr1a = 900
'sprawdzi� czy TIMER1=0 jest potrzebne, w tym rejestrze zmienia si� warto��

On Oc1a Odczytadc Nosave                                    'przy przerwaniu Oc1a (od licznika) skocz do ADC

Enable Oc1a                                                 'w��czenie konkretnego przerwania Oc1a

On Urxc1 Usart_rx Nosave                                    'deklaracja przerwania URXC (odbi�r znaku USART)
On Utxc1 Usart_tx_end Nosave                                'deklaracja przerwania UTXC, koniec nadawania


'deklarowanie zmiennych                                      'adres w�asny
Dim Adrw As Byte                                            'adres odbiorcy 0...15
Dim Adro As Byte                                            ' word bo 2 bity
Dim Srednia As Word
Dim Wartosc As Word
                                                             'ka�dy wysy�a na pocz�tku transmisji, je�eli pojawi si� beggin of frame mastera to nas�uchuje
Const Bof_bit = &B11000000                                  'KOWALCZYK - PDF
Const Bofm_bit = &B10001101
Const Bofmaster_bit = &B11000010
Const Bofs_bit = &B11001101

Const Eofs_bit = &B10001101
Const Eofm_bit = &B10100010

Dim Odbior As Byte
Odbior = 0

rcall usart_init                                            'funkcja kt�ra inicjalizuje usarta
Start Timer1                                               'w��czenie timera

Sei                                                         'w��czenie globalnie przerwa�

Do

'SBI ADCsra, 6
'
'   !czekaj1:
'                                                            'je�eli =0, przeskocz� linijke
'   SBIC ADCSRA, 4
'   RJMP czekaj1
'   Wartosc = Adc / 16
'   Print Adc
'   Waitms 1000


Loop



Odczytadc:
   push rstemp                                              'o ile potrzeba - sprawdzi�
   in rstemp,sreg                                           'o ile potrzeba  - sprawdzi�
   push rstemp                                              'o ile potrzeba - sprawdzi�
   push rsdata                                              'o ile potrzeba  - sprawdzi�
   push yl                                                  'o ile potrzeba  - sprawdzi�
   push yh                                                  'o ile potrzeba  - sprawdzi�
   push r1                                                  'o ile potrzeba  - sprawdzi�
   push r0                                                  'o ile potrzeba  - sprawdzi�
   !cli

   INC Licznik                                              'inkrementacja licznila
   SBI ADCsra, 6

   !czekaj:
                                                            'je�eli =0, przeskocz� linijke
   SBIC ADCSRA, 4
   RJMP czekaj
   Wartosc = Adc / 16
   Print Adc

   sei
   pop r0
   pop r1
   pop yh
   pop yl
   pop rsdata
   pop rstemp
   !out sreg,rstemp
   pop rstemp

   Return

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


!rs_rx:
   in rsdata,udr1
   lDs rstemp, {Odbior}
   cpi rstemp,1
      breq koniec_ramki
   cpi rsdata,bofm_bit
      sbis sreg,1
   ret

   ldi rstemp,1
   sts {Odbior},rstemp
  ret

   !koniec_ramki:
     cpi rsdata, eofm_bit
      sbis sreg,1
     Ret
      ldi rstemp,0
      sts {Odbior},rstemp

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