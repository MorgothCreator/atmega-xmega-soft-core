# atmega-xmega-soft-core

 Mega/Xmega soft core RTL design.

 A preety complete implementation of ATmega/ATxmega soft core.

 This design include all most used IO's, priority interrupt module and watchdog module, except UART that is in development.

  # V00.02.16:

 ```
  -Fix SBIW instruction due to wrong description in oficial documentation.
  -Add simple UART interface.
  -Optimize core code and make it more readable.

 TO DO:
 
 Observed some issues with TIM3 on 'arduboy-rtl-emulator' project, so is needed to 
 "Fix situations where on random times at core reset the TIM3 prescaller is setup at 
 wrong value ( at /64 instead of /8 core clock )" need to check in what situation 
 this issue is manifesting.
 ```

 # V00.02.10:

 ```
 Initial commit.
 Tested on Digilent Nexis Video board.
 ```

  If you like my work, you can help further development by donating as little as 1 EUR.
  
 [![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CZM6JXDVMFXHS&source=url)

 Or you can send some crypto:

 BTC: 3CFRp6day6ZRgpXw8n1QGvXfmk5gf8XK3e

 LBRY: bbVdwfTsVkFhA3qcq2znyD7juuuDnUdMT1

 MONERO: 8ALzMJESPVrdCmrQuwssrZVvdg4wBvtt6DXigYxZ33ZuQVHQBXNpHpoCZVR4smKLHhYPsSgsH4BvYCXdBNdZzFH8AB5z8vs
