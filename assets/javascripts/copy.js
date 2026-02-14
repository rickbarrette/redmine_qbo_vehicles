async function handleCopy(event) {
  console.log("Copy link clicked");
  // 1. Prevent the link from actually navigating
  event.preventDefault();

  // 2. Grab the text from our span
  const text = document.getElementById('vin').innerText;

  try {
    // 3. Write to clipboard
    await navigator.clipboard.writeText(text);
    
    // 4. Update the UI to show it worked
    const link = event.target;
    const originalText = link.innerText;
    link.innerText = "Copied!";
    link.style.color = "#4CAF50"; // Turn green

    // 5. Reset after 2 seconds
    setTimeout(() => {
      // Check if the text is long enough to prevent errors
      if (originalText.length >= 8) {
        const firstPart = originalText.slice(0, -8);
        const lastEight = originalText.slice(-8);
        link.innerHTML = `${firstPart}<b>${lastEight}</b>`;
      } else {
        link.innerText = originalText;
      }
      link.style.color = "";
    }, 2000);

  } catch (err) {
    console.error('Unable to copy', err);
  }
}