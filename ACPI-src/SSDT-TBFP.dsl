/*
 * SSDT-TBFP: power on the Alpine Ridge (JHL6340) Thunderbolt controller at boot
 * so USB-C devices plugged in after a boot with nothing attached can enumerate.
 *
 * Stock BIOS (BECFL357, checked on 0098 DSDT):
 *   - \_SB.TBFP(Arg0 on/off, Arg1 GPIO select) drives the TB force-power GPIO
 *     from GNVS FPG0/FP0L; its only caller is the WMI device \_SB.WMTF.
 *   - \_SB.PCI0.RP05._INI calls PINI() when it exists (CondRefOf), and no
 *     firmware table defines RP05.PINI, so no rename patch is needed.
 * Idea from Lorys89/Intel-NUC8-Hackintosh (SSDT-NUC8), reduced to the TBFP call.
 */
DefinitionBlock ("", "SSDT", 2, "NUC8", "TBFP", 0x00001000)
{
    External (_SB_.TBFP, MethodObj)    // 2 Arguments
    External (_SB_.PCI0.RP05, DeviceObj)
    External (_SB_.PCI0.RP05.LASX, FieldUnitObj)
    External (FPG0, FieldUnitObj)

    Scope (\_SB.PCI0.RP05)
    {
        Method (PINI, 0, Serialized)
        {
            If (_OSI ("Darwin"))
            {
                // Skip if the BIOS left the force-power GPIO unset
                If (CondRefOf (\_SB.TBFP))
                {
                    If ((\FPG0 != Zero))
                    {
                        \_SB.TBFP (One, One)
                        // Wait up to 1 s for the root port link to come up
                        Local0 = Zero
                        While (((LASX == Zero) && (Local0 < 0x64)))
                        {
                            Sleep (0x0A)
                            Local0++
                        }
                    }
                }
            }
        }
    }
}
