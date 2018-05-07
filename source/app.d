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
    float ballSize = 0.01;

    float[numPlayers] racketYCenter = [0, 0];
    float[numPlayers] racketXPosition = [-0.9, 0.9];
    float[numPlayers] racketHalfLength = [0.1, 0.1];
    float[numPlayers] racketHalfWidth = [0.01, 0.01];

    float[numPlayers] racketSpeed = [0.5, 0.5];
    float[2] limits = [-1, 1];
}

enum PlayerOne = 0;
enum PlayerTwo = 1;
GameState state;

void display(ref SDL_Window *screen, ref GameState state)
{
    bool end = true;

    // ****** DISPLAY PART ******
    // Clear screen
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Display first player
    glPushMatrix();

    glColor3f(1., 1., 1.);
    glTranslated(state.racketXPosition[0], state.racketYCenter[0], 0.0);
    glBegin(GL_TRIANGLE_STRIP);

    auto halfLength = state.racketHalfLength[0];
    auto halfWidth = state.racketHalfWidth[0];
    glVertex3d(-halfWidth, -halfLength, 0.0);
    glVertex3d(-halfWidth, halfLength, 0.0);
    glVertex3d(halfWidth, -halfLength, 0.0);
    glVertex3d(halfWidth, halfLength, 0.0);
    glEnd();

    glPopMatrix();

    // Display second player
    glPushMatrix();

    glTranslated(state.racketXPosition[1], state.racketYCenter[1], 0.0);
    glBegin(GL_TRIANGLE_STRIP);

    halfLength = state.racketHalfLength[1];
    halfWidth = state.racketHalfWidth[1];
    glVertex3d(-halfWidth, -halfLength, 0.0);
    glVertex3d(-halfWidth, halfLength, 0.0);
    glVertex3d(halfWidth, -halfLength, 0.0);
    glVertex3d(halfWidth, halfLength, 0.0);
    glEnd();

    glPopMatrix();

    // Display ball
    glPushMatrix();

    glColor3f(1., 1., 0.);
    glTranslated(state.ballPos[0], state.ballPos[1], 0.0);
    glBegin(GL_TRIANGLE_STRIP);

    auto ballSize = state.ballSize;
    glVertex3d(-ballSize, -ballSize, 0.0);
    glVertex3d(-ballSize, ballSize, 0.0);
    glVertex3d(ballSize, -ballSize, 0.0);
    glVertex3d(ballSize, ballSize, 0.0);
    glColor3f(1., 1., 1.);
    glEnd();

    glPopMatrix();

    // Swap buffers
    SDL_GL_SwapWindow(screen);
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
        if (state.ballPos[0] <= state.racketXPosition[0] + state.racketHalfWidth[0] &&
            fabs(state.ballPos[1] - state.racketYCenter[0]) < state.racketHalfLength[0])
        {
            state.ballSpeed[0] *= -1;
        }
    }

    if (state.ballSpeed[0] > 0)
    {
        if (state.ballPos[0] >= state.racketXPosition[1] - state.racketHalfWidth[1] &&
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
    while(!end)
    {
        auto currentTicks = SDL_GetTicks();
        float dt = (currentTicks - prevTicks) / deltaTimeConstant;
        prevTicks = currentTicks;

        updateGameplay(state, dt);
        display(screen, state);

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
