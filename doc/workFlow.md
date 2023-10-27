## Workflow
**PLEASE READ THIS BEFORE YOU START WORKING ON THIS PROJECT!!!**

Here are some development rules that we need to follow:
1. Never ever ever ever commit and push to the main branch. Always use PR(Pull request) to merge your code to the main branch. Your teammate, instead of yourself will review your code and merge it to the main branch.

2. Never ever ever ever just do ```git add --all``` to blindly add all the files to the staging area and commit. You might think, "well, I have a good ```.gitignore``` file so that that keeps me safe from adding unnecessary files to the staging area", but you never know what you might accidentally add to the staging area. It is always a good practice to just ```git add``` the **source files** that you have modified, including **.v* files, **.py* files, or **.md* files. It isn't a good choice to add those *sim-*.yml* files because we change them often. 

3. When you start working, ```git clone``` and ```git checkout -b $(your branch name)```. It is a good practice to name your branch as ```dev-$(your name)```. I name my branch as ```dev-diwang``` for example.

4. Work on your own branch. When you are done with your work, you can commit and push to the remote dev branch. It is possible that there is no remote dev branch. In that case, you need to ```git config push.autoSetupRemote true```. This will allow git to automatically create remote branch that is associated to your local branch.

5. When others have merged their code into the main branch, pull the latest code from the main branch to your local main branch. Then, ```git checkout $(your branch name)``` and ```git merge main```. This will merge the latest code from the main branch to your branch. If there are conflicts, you need to resolve them manually.

6. When you are reviewing other's code, give comments and suggestions. If you think the code is good, you can approve the PR. If you think the code is not good, you can request changes. When you are ready to merge, do squash merge instead of the default merge, which will be the rebase merge. 