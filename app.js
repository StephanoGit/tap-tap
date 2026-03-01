( function () {
  var options = ['Pizza', 'Burger', 'Ramen'];
  var bgClasses = ['bg-pizza', 'bg-burger', 'bg-ramen'];
  var currentIndex = 0;
  var selectedOption = null;
  var confirmed = false;

  var body = document.body;
  var optionDisplay = document.getElementById('option-display');
  var statusEl = document.getElementById('status');

  var DOUBLE_TAP_DELAY = 300;
  var singleTapTimer = null;

  var touchStartY = 0;
  var SWIPE_THRESHOLD = 50;

  function clearBgClasses() {
    body.classList.remove('bg-pizza', 'bg-burger', 'bg-ramen', 'bg-selected', 'bg-confirmed');
  }

  function render() {
    optionDisplay.textContent = options[currentIndex];
    clearBgClasses();
    body.classList.add(bgClasses[currentIndex]);
    statusEl.textContent = '';
  }

  function scrollOption() {
    if (confirmed) return;
    currentIndex = (currentIndex + 1) % options.length;
    selectedOption = null;
    render();
    statusEl.textContent = 'Tap to scroll, double-tap to select';
  }

  function selectOption() {
    if (confirmed) return;
    selectedOption = options[currentIndex];
    clearBgClasses();
    body.classList.add('bg-selected');
    optionDisplay.textContent = selectedOption;
    statusEl.textContent = '"' + selectedOption + '" selected — swipe up to confirm';
  }

  function confirmSelection() {
    if (!selectedOption || confirmed) return;
    confirmed = true;
    clearBgClasses();
    body.classList.add('bg-confirmed');
    optionDisplay.textContent = selectedOption + ' sent';
    statusEl.textContent = '';
    var instructions = document.getElementById('instructions');
    if (instructions) instructions.style.display = 'none';
  }

  /* ---------- Touch handling ---------- */

  body.addEventListener('touchstart', function (e) {
    touchStartY = e.changedTouches[0].clientY;
  }, { passive: true });

  body.addEventListener('touchend', function (e) {
    if (confirmed) return;

    var touchEndY = e.changedTouches[0].clientY;
    var deltaY = touchStartY - touchEndY;

    /* Swipe up detected */
    if (deltaY > SWIPE_THRESHOLD) {
      if (singleTapTimer) {
        clearTimeout(singleTapTimer);
        singleTapTimer = null;
      }
      confirmSelection();
      return;
    }

    /* Tap / double-tap detection */
    if (singleTapTimer) {
      /* Double tap — a pending single-tap exists so this is the second tap */
      clearTimeout(singleTapTimer);
      singleTapTimer = null;
      selectOption();
    } else {
      /* Schedule single tap (wait to rule out double-tap) */
      singleTapTimer = setTimeout(function () {
        scrollOption();
        singleTapTimer = null;
      }, DOUBLE_TAP_DELAY);
    }
  });

  /* ---------- Mouse fallback for desktop testing ---------- */

  var mouseDownY = 0;

  body.addEventListener('mousedown', function (e) {
    mouseDownY = e.clientY;
  });

  body.addEventListener('mouseup', function (e) {
    if (confirmed) return;

    var deltaY = mouseDownY - e.clientY;

    if (deltaY > SWIPE_THRESHOLD) {
      if (singleTapTimer) {
        clearTimeout(singleTapTimer);
        singleTapTimer = null;
      }
      confirmSelection();
      return;
    }

    if (singleTapTimer) {
      clearTimeout(singleTapTimer);
      singleTapTimer = null;
      selectOption();
    } else {
      singleTapTimer = setTimeout(function () {
        scrollOption();
        singleTapTimer = null;
      }, DOUBLE_TAP_DELAY);
    }
  });

  /* Initial render */
  render();
  statusEl.textContent = 'Tap to scroll, double-tap to select';
})();
