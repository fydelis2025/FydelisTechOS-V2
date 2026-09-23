ENTRY(start)

SECTIONS
{
    /* Endereço base de carregamento do kernel (geralmente 1M ou 0x8000) */
    . = 0x8000;

    .text : ALIGN(4096)
    {
        *(.text._start)  /* Garante que o ponto de entrada fique no início absoluto */
        *(.text)
    }

    .rodata : ALIGN(4096)
    {
        *(.rodata)
    }

    .data : ALIGN(4096)
    {
        *(.data)
    }

    .bss : ALIGN(4096)
    {
        *(COMMON)
        *(.bss)
    }
}
