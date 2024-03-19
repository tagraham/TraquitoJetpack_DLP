#include "Application.h"


int main()
{
    App<Application> app;

    app.Run();

    return 0;
}











// #include "App.h"
// #include "Utl.h"

// class Application
// {
// public:
//     void Run()
//     {
//         Log("Iterating 5 to 10");
//         for (auto i : Range(5, 10))
//         {
//             Log("  ", i);
//         }
//         Log("Iterating 0 to 10");
//         for (auto i : Range(0, 10))
//         {
//             Log("  ", i);
//         }
//         Log("Iterating 10 to 0");
//         for (auto i : Range(10, 0))
//         {
//             Log("  ", i);
//         }
//         Log("Iterating 0 to 0");
//         for (auto i : Range(0, 0))
//         {
//             Log("  ", i);
//         }
//         Log("Iterating -5 to -5");
//         for (auto i : Range(-5, -5))
//         {
//             Log("  ", i);
//         }
//         Log("Iterating -5 to -7");
//         for (auto i : Range(-5, -7))
//         {
//             Log("  ", i);
//         }
//         Log("Iterating -5 to 7");
//         for (auto i : Range(-5, 7))
//         {
//             Log("  ", i);
//         }
//     }
// };

// int main()
// {
//     App<Application> app;
//     app.Run();

//     return 0;
// }




// #include "App.h"
// #include "Blinker.h"

// class Application
// {
// public:
//     void Run()
//     {
//         Pin pGps(2, Pin::Type::OUTPUT, 1);
//         Pin pTx(28, Pin::Type::OUTPUT, 1);
//         UartDisable(UART::UART_1);

//         // does not appear to save much of anything at already-low currents
//         static Pin pPowerSave(23);
//         Shell::AddCommand("save", [](vector<string> argList) {
//             if (atoi(argList[0].c_str()))
//             {
//                 pPowerSave.DigitalWrite(0);
//             }
//             else
//             {
//                 pPowerSave.DigitalWrite(1);
//             }
//         }, { .argCount = 1, .help = "power save on(1) or off(0)" });

//         Shell::AddCommand("periph", [](vector<string> argList) {
//             PeripheralControl::DisablePeripheralList({
//                 PeripheralControl::SPI1,
//                 PeripheralControl::SPI0,
//                 PeripheralControl::PWM,
//                 PeripheralControl::PIO1,
//                 PeripheralControl::PIO0,
//                 PeripheralControl::I2C1,
//             });
//         }, { .argCount = 0, .help = "disable unused peripherals" });

//         static Blinker b;
//         b.SetPin(25);
//         b.SetBlinkOnOffTime(250, 750);
//         // b.On();
//         // b.EnableAsyncBlink();

//         USB::SetCallbackConnected([]{ Log("USB Connected"); });
//         USB::SetCallbackDisconnected([]{ Log("USB Disconnected"); });
//         USB::SetCallbackVbusConnected([]{
//             Log("VBUS Sense High");
//             Shell::Eval("usb 1");
//         });
//         USB::SetCallbackVbusDisconnected([]{
//             Log("VBUS Sense Low");
//             Shell::Eval("usb 0");
//         });

//         Shell::Eval("scope clk");
//         Shell::Eval("show");
//     }
// };

// int main()
// {
//     App<Application> app;
//     app.Run();

//     return 0;
// }








// #include "App.h"
// #include "ADC_ADS1115.h"

// class Application
// {
// public:
//     void Run()
//     {
//         ADC_ADS1115::Setup();
//         Shell::Eval("scope adc.1115");
//     }
// };

// int main()
// {
//     App<Application> app;
//     app.Run();

//     return 0;
// }



















// #include "App.h"
// #include "TempSensorInternal.h"

// class Application
// {
// public:
//     void Run()
//     {
//         static uint32_t count = 0;
//         static TimedEventHandlerDelegate tedCount;
//         tedCount.SetCallback([]{
//             ++count;
//         });

//         static uint32_t row = 1;
//         static TimedEventHandlerDelegate tedTest;
//         tedTest.SetCallback([]{
//             Log(row, ", ", TempSensorInternal::GetTempF(), ", ", count, ", ", ADC::GetMilliVolts(26));

//             ++row;
//             count = 0;
//         });

//         Shell::AddCommand("start", [](vector<string> argList) {
//             static TimedEventHandlerDelegate tedPrint;
//             tedPrint.SetCallback([]{
//                 Log("row, tempF, coremark, mV");
//             });
//             tedPrint.RegisterForTimedEvent(0);
//             tedCount.RegisterForTimedEventInterval(0);
//             tedTest.RegisterForTimedEventInterval(1000);
//         }, { .argCount = 0, .help = "" });

//         Shell::AddCommand("stop", [](vector<string> argList) {
//             tedCount.DeRegisterForTimedEvent();
//             tedTest.DeRegisterForTimedEvent();
//             count = 0;
//             row = 1;
//         }, { .argCount = 0, .help = "" });
//     }
// };

// int main()
// {
//     App<Application> app;
//     app.Run();

//     return 0;
// }





















// #include "App.h"

// class Application
// {
// public:
//     void Run()
//     {
//         I2C i2c;
//         static Pin p(28);
//         p.DigitalWrite(0);

//         Log("Run()");
//         for (uint8_t addr = 0; addr < (1 << 7); ++addr)
//         {
//             if (addr % 16 == 0) {
//                 LogNNL(ToHex(addr), " ");
//             }

//             bool ret = i2c.CheckAddr(addr);

//             LogNNL(ret ? "X" : "-");
//             LogNNL(addr % 16 == 15 ? "\n" : "  ");
//         }

//         Log("Run Done");
//     }
// };

// int main()
// {
//     App<Application> app;
//     app.Run();

//     return 0;
// }






