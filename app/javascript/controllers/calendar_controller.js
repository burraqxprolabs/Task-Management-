// app/javascript/controllers/calendar_controller.js
import { Controller } from "@hotwired/stimulus"

// We use FullCalendar via CDN on the calendar view page
// The CSS is included in the view's head, and JS is loaded via script tags there.
// This controller expects the scripts to be present on the page.
export default class extends Controller {
  static values = {
    eventsUrl: String
  }

  connect() {
    if (!window.FullCalendar || !window.FullCalendar.Calendar) {
      console.error("FullCalendar is not loaded. Ensure CDN scripts are included in the view.")
      return
    }

    const calendarEl = this.element
    const Calendar = window.FullCalendar.Calendar
    const dayGridPlugin = window.dayGridPlugin

    this.calendar = new Calendar(calendarEl, {
      plugins: dayGridPlugin ? [dayGridPlugin] : [],
      initialView: 'dayGridMonth',
      height: 'auto',
      editable: true,
      eventDurationEditable: false,
      events: (info, success, failure) => {
        const url = new URL(this.eventsUrlValue, window.location.origin)
        url.searchParams.set('start', info.startStr)
        url.searchParams.set('end', info.endStr)
        fetch(url, { headers: { 'Accept': 'application/json' }})
          .then(r => r.json())
          .then(data => success(data))
          .catch(err => failure(err))
      },
      eventDrop: (info) => {
        // Persist new date to server on drop
        const id = info.event.id
        const newDate = info.event.startStr // ISO date (allDay)
        const tokenTag = document.querySelector('meta[name="csrf-token"]')
        const csrfToken = tokenTag && tokenTag.getAttribute('content')

        fetch(`/tasks/${id}.json`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': csrfToken || ''
          },
          body: JSON.stringify({ task: { due_date: newDate } })
        }).then(res => {
          if (!res.ok) throw new Error('Failed to update')
        }).catch(err => {
          console.error(err)
          info.revert()
        })
      },
      eventClick: (info) => {
        info.jsEvent.preventDefault()
        const url = info.event.url
        if (!url) return
        if (window.Turbo && typeof window.Turbo.visit === 'function') {
          window.Turbo.visit(url, { frame: 'task_modal' })
        } else {
          // Fallback: programmatic link click targeted at the frame
          const a = document.createElement('a')
          a.href = url
          a.dataset.turboFrame = 'task_modal'
          document.body.appendChild(a)
          a.click()
          a.remove()
        }
      }
    })

    this.calendar.render()
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
      this.calendar = null
    }
  }
}
