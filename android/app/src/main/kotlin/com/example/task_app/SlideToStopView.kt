package com.example.task_app

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.max
import kotlin.math.min

/**
 * Minimal "slide to stop" control used by [AlarmActivity]. A rounded track
 * with an amber thumb; dragging the thumb to the right edge fires [listener].
 * Releasing early springs the thumb back via [ObjectAnimator].
 */
class SlideToStopView : View {

    fun interface Listener {
        fun onSlideToStop()
    }

    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val trackBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val thumbPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val thumbActivePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    private val radius = dp(14f)
    private var trackTop = 0f
    private var trackBottom = 0f
    private var thumbSize = 0f
    private var minX = 0f
    private var maxX = 0f

    /** Left edge of the thumb in px while the user drags it. */
    private var thumbX = 0f
    private var dragging = false
    private var springBack: ObjectAnimator? = null

    private var listener: Listener? = null

    constructor(context: Context) : super(context) {
        init()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        init()
    }

    private fun init() {
        trackPaint.color = 0xB3181C2E.toInt()
        trackPaint.style = Paint.Style.FILL

        trackBorderPaint.color = 0x2EFFFFFF.toInt()
        trackBorderPaint.style = Paint.Style.STROKE
        trackBorderPaint.strokeWidth = dp(1f)

        thumbPaint.color = 0xFFFFB74D.toInt()
        thumbPaint.style = Paint.Style.FILL

        thumbActivePaint.color = 0xFFFF9D2B.toInt()
        thumbActivePaint.style = Paint.Style.FILL

        hintPaint.color = 0xCCF2F3F7.toInt()
        hintPaint.textSize = sp(13f)
        hintPaint.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        hintPaint.textAlign = Paint.Align.CENTER
        setOnClickListener { /* handled via drag only */ }
    }

    fun setOnSlideStopListener(l: Listener?) {
        listener = l
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        thumbSize = h.toFloat() - dp(10f)
        val verticalMargin = (h - thumbSize) / 2f
        trackTop = verticalMargin
        trackBottom = verticalMargin + thumbSize
        minX = dp(5f)
        maxX = w.toFloat() - thumbSize - minX
        thumbX = minX
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val desired = dp(72f).toInt()
        val w = resolveSize(desired, widthMeasureSpec)
        val h = resolveSize(dp(56f).toInt(), heightMeasureSpec)
        setMeasuredDimension(w, h)
    }

    private fun trackRect(): RectF = RectF(minX, trackTop, maxX + thumbSize, trackBottom)

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawRoundRect(trackRect(), radius, radius, trackPaint)
        canvas.drawRoundRect(trackRect(), radius, radius, trackBorderPaint)

        val thumbIsFilled = dragging || thumbX > minX + dp(2f)

        val thumbRect = RectF(thumbX, trackTop, thumbX + thumbSize, trackBottom)
        canvas.drawRoundRect(thumbRect, radius, radius, if (thumbIsFilled) thumbActivePaint else thumbPaint)

        val label = "STOP"
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        labelPaint.color = 0xFF221704.toInt()
        labelPaint.textSize = sp(11f)
        labelPaint.typeface = Typeface.create("sans-serif", Typeface.BOLD)
        labelPaint.textAlign = Paint.Align.CENTER
        val f = labelPaint.fontMetrics
        val baseline = (thumbRect.top + thumbRect.bottom - f.ascent - f.descent) / 2f
        canvas.drawText(label, thumbRect.centerX(), baseline, labelPaint)

        if (!thumbIsFilled) {
            val hf = hintPaint.fontMetrics
            val hintBaseline = (trackTop + trackBottom - hf.ascent - hf.descent) / 2f
            canvas.drawText("Slide to Stop", (minX + maxX + thumbSize) / 2f, hintBaseline, hintPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        springBack?.cancel()
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                if (insideThumb(event.x)) {
                    dragging = true
                    parent?.requestDisallowInterceptTouchEvent(true)
                    invalidate()
                    return true
                }
                return false
            }
            MotionEvent.ACTION_MOVE -> {
                if (dragging) {
                    thumbX = clamp(event.x - thumbSize / 2f, minX, maxX)
                    if (thumbX >= maxX - dp(2f)) {
                        dragging = false
                        listener?.onSlideToStop()
                    }
                    invalidate()
                    return true
                }
                return false
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) {
                    dragging = false
                    animateBack()
                    return true
                }
                return false
            }
        }
        return super.onTouchEvent(event)
    }

    private fun insideThumb(x: Float): Boolean =
        x >= thumbX && x <= thumbX + thumbSize

    private fun animateBack() {
        springBack = ObjectAnimator.ofFloat(this, "thumbX", thumbX, minX)
        springBack?.duration = 260L
        springBack?.interpolator = android.view.animation.DecelerateInterpolator()
        springBack?.addUpdateListener { invalidate() }
        springBack?.start()
    }

    private fun clamp(v: Float, lo: Float, hi: Float) = min(max(v, lo), hi)

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
    private fun sp(v: Float): Float = v * resources.displayMetrics.scaledDensity
}