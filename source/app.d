import std.stdio;
import derelict.sdl2.sdl;
import derelict.opengl;

//mixin glFreeFuncs!(GLVersion.gl33);
//mixin glContext!(GLVersion.gl33);
//GLContext context;

enum maxGLVersion = GLVersion.gl33;
enum supportDeprecated = true;

// Required imports
static if(!supportDeprecated) mixin(glImports);
else mixin(gl_depImports);

// Type declarations should be outside of the struct
mixin glDecls!(maxGLVersion, supportDeprecated);
//struct MyContext {
    mixin glFuncs!(maxGLVersion, supportDeprecated);
    mixin glLoaders!(maxGLVersion, supportDeprecated);
//}
//MyContext context;

alias vec2f = float[2];

enum Player { One, Two }

void InitSDL(ref SDL_Window *screen, ref SDL_GLContext context)
{
    DerelictGL3.load();

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        writefln("SDL_Init Error: %s", SDL_GetError());
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_Window *scr = SDL_CreateWindow("Automatic PONG",
                                          SDL_WINDOWPOS_UNDEFINED,
                                          SDL_WINDOWPOS_UNDEFINED,
                                          640, 480,
                                          SDL_WINDOW_OPENGL);
    if (!scr)
    {
        writefln("Error creating screen: %s", SDL_GetError());
        return;
    }

    context = SDL_GL_CreateContext(scr);

    glEnable(GL_DEPTH_TEST);

    screen = scr;
}

struct GameState
{
    static enum numPlayers = 2;
    float eps = 0.001;

    vec2f ballPos = 0.;
    vec2f ballSpeed = 0.4;

    float[numPlayers] racketYCenter = [0, 0];
    float[numPlayers] racketXPosition = [-0.9, 0.9];
    float[numPlayers] racketHalfLength = [0.01, 0.01];
    float[numPlayers] racketHalfWidth = [0.01, 0.01];

    float[numPlayers] racketSpeed = [0.5, 0.5];
    float[2] limits = [-1, 1];
}

enum PlayerOne = 0;
enum PlayerTwo = 1;
GameState state;

void display(ref SDL_Window *screen, FpsCounter fps, ref GameState state)
{
    bool end = true;


    // ****** DISPLAY PART ******
    // Clear screen
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Display first player
    glPushMatrix();

    glColor3f(1., 1., 1.);
    glTranslated(-0.9, state.racketYCenter[0], 0.0);
    glBegin(GL_TRIANGLE_STRIP);
    glVertex3d(-0.01, -0.1, 0.0);
    glVertex3d(-0.01,  0.1, 0.0);
    glVertex3d( 0.01, -0.1, 0.0);
    glVertex3d( 0.01,  0.1, 0.0);
    glEnd();

    glPopMatrix();

    // Display second player
    glPushMatrix();

    glTranslated( 0.9, state.racketYCenter[1], 0.0);
    glBegin(GL_TRIANGLE_STRIP);
    glVertex3d(-0.01, -0.1, 0.0);
    glVertex3d(-0.01,  0.1, 0.0);
    glVertex3d( 0.01, -0.1, 0.0);
    glVertex3d( 0.01,  0.1, 0.0);
    glEnd();

    glPopMatrix();

    // Display ball
    glPushMatrix();

    glColor3f(1., 1., 0.);
    glTranslated( state.ballPos[0], state.ballPos[1], 0.0);
    glBegin(GL_TRIANGLE_STRIP);
    glVertex3d(-0.01, -0.01 * 16 / 9, 0.0);
    glVertex3d(-0.01,  0.01 * 16 / 9, 0.0);
    glVertex3d( 0.01, -0.01 * 16 / 9, 0.0);
    glVertex3d( 0.01,  0.01 * 16 / 9, 0.0);
    glColor3f(1., 1., 1.);
    glEnd();

    glPopMatrix();

    float x = -0.8;
    float y = -0.8;
    DrawNumber(fps.get(), x, y);

    // Swap buffers
    SDL_GL_SwapWindow(screen);
}

void DrawOne()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d( 0.0, -0.1, 0.0); glVertex3d( 0.0,  0.1, 0.0);
    glEnd();
}

void DrawTwo()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d( 0.1, -0.1, 0.0); glVertex3d(-0.1, -0.1, 0.0); glVertex3d(-0.1,  0.0, 0.0);
    glVertex3d( 0.1,  0.0, 0.0); glVertex3d( 0.1,  0.1, 0.0); glVertex3d(-0.1,  0.1, 0.0);
    glEnd();
}

void DrawThree()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d(-0.1, -0.1, 0.0); glVertex3d( 0.1, -0.1, 0.0); glVertex3d( 0.1,  0.0, 0.0);
    glVertex3d(-0.1,  0.0, 0.0);
    glVertex3d( 0.1,  0.0, 0.0); glVertex3d( 0.1,  0.1, 0.0); glVertex3d(-0.1,  0.1, 0.0);
    glEnd();
}

void DrawFour()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d(-0.1,  0.1, 0.0); glVertex3d(-0.1,  0.0, 0.0); glVertex3d( 0.1,  0.0, 0.0);
    glVertex3d( 0.1,  0.1, 0.0); glVertex3d( 0.1, -0.1, 0.0);
    glEnd();
}

void DrawFive()
{
    glPushMatrix();
    glScaled(-1.0, 1.0, 1.0);
    DrawTwo();
    glPopMatrix();
}

void DrawSix()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d(-0.1,  0.1, 0.0); glVertex3d(-0.1, -0.1, 0.0); glVertex3d( 0.1, -0.1, 0.0);
    glVertex3d( 0.1,  0.0, 0.0); glVertex3d(-0.1,  0.0, 0.0);
    glEnd();
}

void DrawSeven()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d(-0.1,  0.1, 0.0); glVertex3d( 0.1,  0.1, 0.0); glVertex3d( 0.1, -0.1, 0.0);
    glEnd();
}

void DrawHeight()
{
    DrawTwo();
    DrawFive();
}

void DrawNine()
{
    glPushMatrix();
    glScaled(-1.0,-1.0, 1.0);
    DrawSix();
    glPopMatrix();
}

void DrawZero()
{
    glBegin(GL_LINE_STRIP);
    glVertex3d(-0.1,  0.1, 0.0); glVertex3d( 0.1,  0.1, 0.0); glVertex3d( 0.1, -0.1, 0.0);
    glVertex3d(-0.1, -0.1, 0.0); glVertex3d(-0.1,  0.1, 0.0);
    glEnd();
}

void DrawDigit(char _digit)
{
    switch(_digit)
    {
    case 0: DrawZero();
        break;
    case 1: DrawOne();
        break;
    case 2: DrawTwo();
        break;
    case 3: DrawThree();
        break;
    case 4: DrawFour();
        break;
    case 5: DrawFive();
        break;
    case 6: DrawSix();
        break;
    case 7: DrawSeven();
        break;
    case 8: DrawHeight();
        break;
    case 9: DrawNine();
        break;
    default:
        break;
    }
}

void DrawNumber(int _number, float _x, float _y)
{
    import std.math : log10;

    _x += log10(cast(double)_number) * 0.24;

    while (_number != 0)
    {
        char digit = cast(char) (_number % 10);

        glPushMatrix();
        glTranslated(_x, _y, 0.0);
        DrawDigit(digit);
        glPopMatrix();

        _number /= 10;
        _x -= 0.24;
    }
}

class FpsCounter
{
    private int m_prevTick;
    private int[] m_fps = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    private int m_fpsIndex = 0;

    this()
    {
        m_prevTick = SDL_GetTicks();
    }

    int get()
    {
        import std.algorithm.iteration : sum;

        int currentTick = SDL_GetTicks();
        float dt = cast(float)(currentTick - m_prevTick) / 1000.;
        m_prevTick = currentTick;

        if (dt != 0.)
        {
            int cfps = cast(int) (1. / dt);
            m_fps[m_fpsIndex++] = cfps;
            m_fpsIndex %= 10;
            return sum(m_fps) / 10;
        }
        return 0;
    }
}

import std.stdio;

void updateBall(ref GameState state, float dt)
{
    for (int i = 0; i < state.ballPos.length; i++)
    {
        state.ballPos[i] += dt * state.ballSpeed[i];
    }
}

void updatePlayers(ref GameState state, float dt)
{
    import std.math : fabs;
    
    for (int i = 0; i < state.numPlayers; i++)
    {
        float yDiff = state.racketYCenter[i] - state.ballPos[1];
        if (fabs(yDiff) < state.eps)
            continue;

        float dy = -yDiff / fabs(yDiff);
        state.racketYCenter[i] += dy * dt * state.racketSpeed[i];
    }
}

void checkCollisons(ref GameState state)
{
    import std.math : fabs;

    if (state.ballSpeed[0] < 0)
    {
        if (state.ballPos[0] <= state.racketXPosition[0] + state.racketHalfLength[0] &&
            fabs(state.ballPos[1] - state.racketYCenter[0]) < state.racketHalfLength[0])
        {
            state.ballSpeed[0] *= -1;
        }
    }

    if (state.ballSpeed[0] > 0)
    {
        writeln(state.ballPos[0]);
        if (state.ballPos[0] >= state.racketXPosition[1] - state.racketHalfLength[1] &&
            fabs(state.ballPos[1] - state.racketYCenter[1]) < state.racketHalfLength[1])
        {
            state.ballSpeed[0] *= -1;
        }
    }

    if (state.ballPos[1] <= state.limits[0])
        state.ballSpeed[1] *= -1;
    if (state.ballPos[1] >= state.limits[1])
        state.ballSpeed[1] *= -1;
}


void updateGameplay(ref GameState state, float dt)
{
    import std.math : fabs;

    checkCollisons(state);
    updateBall(state, dt);
    updatePlayers(state, dt);
}

void main() {
    SDL_Window * screen = null;
    SDL_GLContext context = null;

    auto prevTicks = SDL_GetTicks();
    float deltaTimeConstant = 1000.;
    InitSDL(screen, context);

    bool end = false;
    auto fps = new FpsCounter();
    while(!end)
    {
        auto currentTicks = SDL_GetTicks();
        float dt = (currentTicks - prevTicks) / deltaTimeConstant;
        prevTicks = currentTicks;

        updateGameplay(state, dt);
        display(screen, fps, state);

        // Check events
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            switch (event.type)
            {
                // Quit the program
                case SDL_QUIT:
                    end = true;
                default:
                    break;
            }
        }
    }

    scope(exit) SDL_Quit();
    SDL_GL_DeleteContext(context);
}
