# Bomb-Defusal-Game
Project Description:
This project will involve building an interactive bomb defusal simulation where the user must solve different puzzles and complete tasks to successfully defuse a simulated bomb before the timer runs out.

Testable Features:
Crack the PIN: The main idea in this game is that the player should discover a four digit code where there are numbers that are hidden between 0 to 5. The buttons will allow you to toggle between each number in order to represent numbers from 0 to 5 and confirm one digit at a time using the keys mentioned on the VGA. When confirming the number for the digit it will light up the led displaying you completed that digit. The VGA displays feedback indicating how close they are to each digit to the correct PIN. 
- Correct: Digit is in the correct position
- Close: Digital exists in the PIN but the wrong position
- Not Here: The Digit does not exist in the PIN

Memory Sequence: This system will display positions on a 3×3 imaginary grid where each position will have its respective row and column displayed on the VGA. The player will recreate the sequence using the switches to choose the coordinates and the button to confirm the same. When activating the switches for the sequence if  more than one button is pressed the VGA will display Slide one switch only. The sequence will also light up on one of the 9 led to know which switches are used during the sequence. The length of the sequence will be 4 and after all were correct you successfully defused the bomb. 
Overall Game Control: Common countdown timer shown on the seven-segment display. Progressing to the next puzzle after successful completion of the current one. Successful completion feedback after successful completion of all two puzzles and failure feedback if the time runs out. Also, as adding a reset button to start the game from the beginning

Combinational and Sequential Logic:
The combinational logic checks the memory sequence answers and compares each guess digit of the PIN against the actual code to generate LED display output. The sequential logic will hold 4-digit PIN number, memory sequence, user input and puzzle progress status. Counters will regulate the common countdown and LED blinking operations.
