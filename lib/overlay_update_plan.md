# Plan for Updating the Via Overlay Design

1. **Improve Text Readability**:
   - Change the overlay background to a more opaque color or add a solid color behind the text to enhance contrast.
   - Implement a gradient overlay that darkens the background behind the text to ensure better visibility.

2. **Integrate Microphone and Keyboard Tabs**:
   - Add a microphone icon that allows users to "talk" to Via directly within the overlay.
   - Implement a keyboard tab that brings up the phone's keyboard for text input, ensuring both functionalities are accessible in the smaller (pre-expanded) screen.

3. **Address UI Issues**:
   - Ensure the overlay is responsive to the keyboard being displayed, adjusting its size and position to prevent buttons from going off-screen.
   - Fix the gradient cut-off issue that affects text visibility, ensuring that all text is readable regardless of the background.

4. **Testing and Feedback**:
   - After implementing the changes, conduct thorough testing to ensure that the overlay functions correctly and that the text is readable.
   - Gather user feedback to refine the design further and make any necessary adjustments.

### Follow-Up Steps:
- Implement the changes in the `via_overlay.dart` file.
- Test the overlay in various scenarios (e.g., with the keyboard open, different screen sizes).
- Update any relevant documentation or user guides to reflect the new features and design.
