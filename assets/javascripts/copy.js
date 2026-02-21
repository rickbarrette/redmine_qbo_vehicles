async function handleCopy(event) {
  console.log("Copy link clicked");
  
  let text;
  let link;
  // Grab the text from our clicked link
  if(event.target.tagName.toLowerCase() === 'b'){
    text = event.target.parentElement.innerText;
    link = event.target.parentElement;
  } else {
    text = event.target.innerText;
    link = event.target;
  }

  try {
    // Write to clipboard
    await navigator.clipboard.writeText(text);
    
    // Update the UI to show it worked
    const originalText = link.innerText;
    link.innerHTML = "<b>Copied!</b>";
    link.style.color = "#4CAF50"; // Turn green

    // Reset after 2 seconds
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