# Frame in the Assembler

## General information

The program produces a frame of different sizes, colors, and text in graphics memory. The frame is created using the 'ASM' programming language.

## Program start

We use the "DOS-box" emulator
In the command line, enter
```ASM
>>> new_frame.asm
>>> tlink /t new_frame.obj
>>> new_fram.com <fr_len> <fr_high> <frame_colour> <frame_kind> <heading>:<text>.
```

## Example

Input:

![s](https://github.com/A-Elbereth-Gilthoniel/images/blob/main/frame_input.png)

Output:

![sd](https://github.com/A-Elbereth-Gilthoniel/images/blob/main/frame_output.png)
