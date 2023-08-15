/**
 * Math game
 *
 * Generates a math question and three possible answers, one of which is correct.
 * An undeveloped example script.
 */

local regenerate_on_answer = false;     // generates a new math problem when any answer is given
local regenerate_on_solve = true;       // generates a new math problem when the correct answer is given

// ----------------------------------------------------------------------------------------------------

hud_chat <- Constants.EHudNotify.HUD_PRINTTALK;

enum Operator {
    Subtract,
    Add,
    Multiply,
    // Divide,
    Max
}

// ----------------------------------------------------------------------------------------------------

local worldtexts = [];
local choice_ents = { answer1 = {}, answer2 = {}, answer3 = {} };
local question_display_ent = null;
local correct_answer_ent = null;

// ----------------------------------------------------------------------------------------------------

function OnPostSpawn()
{
    local len = EntityGroup.len();
    local invalid_entities_found = false;

    for (local i = 0; i < len; i++)
    {
        if (!EntityGroup[i].IsValid())
        {
            printl(self + format(" EntityGroup[%d] is not a valid entity: ", i) + EntityGroup[i]);
            invalid_entities_found = true;
        }
    }

    if (invalid_entities_found)
    {
        printl(self + " The game won't work because one of the question and answer entities is not valid");
        return; // fail here
    }

    question_display_ent = EntityGroup[0];

    choice_ents.answer1.choice <- EntityGroup[1];
    choice_ents.answer1.display <- EntityGroup[2];

    choice_ents.answer2.choice <- EntityGroup[3];
    choice_ents.answer2.display <- EntityGroup[4];

    choice_ents.answer3.choice <- EntityGroup[5];
    choice_ents.answer3.display <- EntityGroup[6];

    // for (local i = 0; i < len; i++)
    // {
    //     printl(self + format(" EntityGroup[%d] == ", i) + EntityGroup[i]);
    // }
}

// ----------------------------------------------------------------------------------------------------

function CreateMathProblem()
{
    // operator type
    local operator = RandomInt(0, Operator.Max - 1);

    // operands
    local operand1 = RandomInt(1, 10);
    local operand2 = RandomInt(1, 10);

    // answers
    local correct_answer = CalculateAnswer(operator, operand1, operand2);
    local wrong_answer1 = CalculateAnswer(operator, operand1 - RandomInt(1, 2), operand2);
    local wrong_answer2 = CalculateAnswer(operator, operand1, operand2 + RandomInt(1, 2));

    // human words for the operation
    local operation = null;

    switch (operator) {
        case Operator.Subtract:
            operation = "minus"
            break;
        case Operator.Add:
            operation = "plus"
            break;
        case Operator.Multiply:
            operation = "times"
            break;
        // case Operator.Divide:   // will produce a float. add checks later
        //     operation = "divided by"
        //     break;
    }

    local question = format("What is %d %s %d?", operand1, operation, operand2);
    // local answers = format("Answers: correct: %d, incorrect1: %d, incorrect2: %d", correct_answer, wrong_answer1, wrong_answer2);

    // ClientPrint(null, hud_chat, question);
    // ClientPrint(null, hud_chat, answers);

    // kill old worldtexts  // TODO look into releasing strings
    foreach (pwt in worldtexts)
    {
        if (pwt.IsValid())
        {
            pwt.Destroy();
        }
    }

    worldtexts.clear();

    // display question
    PlacePointWorldtext(question, question_display_ent.GetOrigin());

    // store answers in an array
    local answers = [];
    answers.push(correct_answer);
    answers.push(wrong_answer1);
    answers.push(wrong_answer2);

    // assign each choice entity an answer
    foreach (choice in choice_ents)
    {
        local index = RandomInt(0, answers.len() - 1);
        local answer = answers[index];

        // display answer
        PlacePointWorldtext(answer.tostring(), choice.display.GetOrigin(), 20);

        // if this answer is correct, store it
        if (answer == correct_answer)
        {
            correct_answer_ent = choice.choice;
        }

        // remove the answer from the array
        answers.remove(index);
    }
}

function CalculateAnswer(operator, operand1, operand2)
{
    local answer = 0;   // integers only for now

    switch (operator) {
        case Operator.Subtract:
            answer = operand1 - operand2;
            break;
        case Operator.Add:
            answer = operand1 + operand2;
            break;
        case Operator.Multiply:
            answer = operand1 * operand2;
            break;
    //     case Operator.Divide:   // will produce a float. add checks later
    //         answer = operand1 / operand2;
    //         break;
    }

    return answer;
}

function TryAnswer()
{
    // is caller the correct answer ent
    if (caller == correct_answer_ent)
    {
        ClientPrint(activator, hud_chat, "You are correct! You won't die today");

        if (regenerate_on_solve)
        {
            CreateMathProblem();
        }
    }
    else
    {
        FizzlePlayer(activator);
        ClientPrint(activator, hud_chat, "No! I don't want that!");

        if (regenerate_on_answer)
        {
            CreateMathProblem();
        }
    }
}

// ----------------------------------------------------------------------------------------------------

function PlacePointWorldtext(message, origin, textsize = 10)
{
    local pwt = CreatePointWorldtext(message, textsize);

    if (pwt != null)
    {
        worldtexts.push(pwt);

        // pwt.SetOrigin(Vector(origin.x, origin.y, origin.z + 48));    // vertical offset
        pwt.SetOrigin(origin);
    }
}

function CreatePointWorldtext(message, textsize = 10)
{
    local pwt = SpawnEntityFromTable("point_worldtext", {
        color           = "255 255 255 255"
        font            = 0
        message         = message
        orientation     = 1
        rainbow         = 0
        targetname      = ""
        textsize        = textsize
        textspacingx    = 0.0
        textspacingy    = 0.0
    });

    return pwt;
}

// ----------------------------------------------------------------------------------------------------

function FizzlePlayer(player)
{
	// Cow Mangler
    player.TakeDamageCustom(null, player, null, Vector(0, 0, 0), player.GetOrigin(), player.GetHealth(), 0, Constants.ETFDmgCustom.TF_DMG_CUSTOM_PLASMA);
}